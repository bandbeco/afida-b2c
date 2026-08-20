# Rails loads every fixture table in one batch wrapped in
# disable_referential_integrity, which issues ALTER TABLE ... DISABLE TRIGGER
# ALL. PostgreSQL only lets a SUPERUSER disable the system triggers that back
# foreign keys — table ownership is not enough. When the role lacks that,
# Rails prints a warning, carries on, and every fixture-based test then dies on
# the same foreign-key violation, because fixtures are inserted in alphabetical
# table order (addresses before users).
#
# The resulting output is thousands of identical stack traces that say nothing
# about the actual cause. This check runs once at boot and replaces them with a
# single message naming the two fixes.
module ReferentialIntegrityCheck
  ProbeSucceeded = Class.new(StandardError)

  module_function

  # Returns nil when fixtures will load, or an actionable message when they
  # will not.
  def failure_message(connection)
    return nil if can_disable_referential_integrity?(connection)

    config = ActiveRecord::Base.connection_db_config.configuration_hash
    role = config[:username] || ENV["PGUSER"] || ENV["USER"]

    <<~MESSAGE
      Cannot load fixtures: the PostgreSQL role #{role.inspect} may not disable
      referential integrity on database #{config[:database].inspect}.

      Every fixture-based test would fail with a misleading foreign-key error,
      because Rails inserts fixture tables alphabetically and relies on being
      able to switch foreign-key checks off first.

      Fix it with EITHER of these, as a superuser:

        ALTER ROLE #{role} SUPERUSER;

      or, more narrowly (PostgreSQL 15+), grant only the one privilege needed:

        GRANT SET ON PARAMETER session_replication_role TO #{role};

      See docs/runbooks/local-test-database.md.
    MESSAGE
  end

  # Checking is_superuser directly would be wrong: it misses roles granted only
  # the narrower parameter privilege, which the adapter override below makes
  # sufficient.
  def can_disable_referential_integrity?(connection)
    can_set_replication_role?(connection) || can_disable_triggers?(connection)
  end

  # PostgreSQL 15+ lets a superuser hand out this one setting on its own, via
  # GRANT SET ON PARAMETER. SET LOCAL keeps the probe inside the transaction, so
  # the rollback undoes it.
  def can_set_replication_role?(connection)
    connection.transaction(requires_new: true) do
      connection.execute("SET LOCAL session_replication_role = replica")
      raise ProbeSucceeded
    end
    false
  rescue ProbeSucceeded
    true
  rescue ActiveRecord::ActiveRecordError
    false
  end

  # Mirrors exactly what Rails will attempt, then rolls it back. The probe
  # deliberately picks a table that HAS a foreign key: DISABLE TRIGGER ALL on a
  # table without one has no system triggers to refuse, so it succeeds for any
  # owner and would report a capability the role does not have.
  def can_disable_triggers?(connection)
    table = connection.select_value(
      "SELECT conrelid::regclass::text FROM pg_constraint WHERE contype = 'f' LIMIT 1"
    )
    return true if table.nil? # no foreign keys anywhere: nothing to disable

    connection.transaction(requires_new: true) do
      connection.execute("ALTER TABLE #{connection.quote_table_name(table)} DISABLE TRIGGER ALL")
      # Undoes the probe. Deliberately not ActiveRecord::Rollback: that is an
      # ActiveRecordError, so the rescue below could not tell a successful
      # probe from a refused one.
      raise ProbeSucceeded
    end
    false
  rescue ProbeSucceeded
    true
  rescue ActiveRecord::ActiveRecordError
    false
  end

  # A SEPARATE privilege from disabling the triggers. After loading fixtures
  # Rails calls check_all_foreign_keys_valid!, which UPDATEs pg_catalog
  # .pg_constraint directly to re-validate every constraint. Writing a system
  # catalog is superuser-only and cannot be granted, so a role relying on the
  # narrow session_replication_role grant gets past the insert and fails here
  # instead — reported, misleadingly again, as invalid fixture data.
  #
  # The probe writes nothing: WHERE false still permission-checks at execution.
  def can_verify_foreign_keys?(connection)
    connection.transaction(requires_new: true) do
      connection.update("UPDATE pg_catalog.pg_constraint SET convalidated = convalidated WHERE false")
      raise ProbeSucceeded
    end
    false
  rescue ProbeSucceeded
    true
  rescue ActiveRecord::ActiveRecordError
    false
  end

  # Stock Rails disables foreign keys with ALTER TABLE ... DISABLE TRIGGER ALL,
  # which PostgreSQL restricts to superusers. Setting session_replication_role
  # has the same effect on foreign-key triggers and can be granted on its own,
  # so a development role never needs superuser just to run the test suite.
  #
  # Roles that CAN use the stock path keep using it: this only takes over when
  # Rails' own approach would fail.
  module ViaSessionReplicationRole
    def disable_referential_integrity
      return super if stock_disable_referential_integrity_works?

      execute("SET session_replication_role = replica")
      begin
        yield
      ensure
        # Mirrors Rails' own re-enable, which likewise swallows errors here so a
        # failure restoring the setting cannot mask the caller's exception.
        begin
          execute("SET session_replication_role = DEFAULT")
        rescue ActiveRecord::ActiveRecordError
          nil
        end
      end
    end

    private

    def stock_disable_referential_integrity_works?
      return @stock_disable_referential_integrity_works if defined?(@stock_disable_referential_integrity_works)

      @stock_disable_referential_integrity_works =
        ReferentialIntegrityCheck.can_disable_triggers?(self)
    end
  end
end

ActiveSupport.on_load(:active_record_postgresqladapter) do
  prepend ReferentialIntegrityCheck::ViaSessionReplicationRole
end
