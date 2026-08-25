require "test_helper"

# Guards the check that turns "3000 confusing foreign-key errors" into one
# actionable message. See test/support/referential_integrity_check.rb.
class ReferentialIntegrityCheckTest < ActiveSupport::TestCase
  # Stands in for a connection whose role may not disable system triggers.
  # Rails only needs these four methods from the real adapter.
  class FakeConnection
    def initialize(raise_on_alter:)
      @raise_on_alter = raise_on_alter
    end

    def select_value(_sql) = "addresses"
    def update(_sql) = 0
    def quote_table_name(name) = %("#{name}")

    def transaction(**)
      raise ActiveRecord::StatementInvalid, "permission denied" if @raise_on_alter
      yield
    end

    def execute(_sql) = nil
  end

  test "reports no problem when the connection can disable referential integrity" do
    assert_nil ReferentialIntegrityCheck.failure_message(FakeConnection.new(raise_on_alter: false))
  end

  test "reports a problem when the connection cannot disable referential integrity" do
    assert_not_nil ReferentialIntegrityCheck.failure_message(FakeConnection.new(raise_on_alter: true))
  end

  test "the failure message offers both remedies, since superuser is not always grantable" do
    message = ReferentialIntegrityCheck.failure_message(FakeConnection.new(raise_on_alter: true))

    assert_match(/SUPERUSER/, message)
    assert_match(/GRANT SET ON PARAMETER session_replication_role/, message)
  end

  # The whole point is failing fast, so the message has to say what to do,
  # not just what went wrong.
  test "the failure message names the role and database actually in use" do
    message = ReferentialIntegrityCheck.failure_message(FakeConnection.new(raise_on_alter: true))
    config = ActiveRecord::Base.connection_db_config.configuration_hash

    assert_match(/#{Regexp.escape(config[:database])}/, message)
  end

  # Belt and braces: the real test connection must be capable, or every
  # fixture-based test in this suite is running on borrowed luck.
  # Separate privilege, separate probe: after loading fixtures Rails runs
  # check_all_foreign_keys_valid!, which UPDATEs pg_catalog.pg_constraint
  # directly. That is superuser-only and no GRANT covers it, so a role using the
  # narrow session_replication_role grant clears the first hurdle and trips this
  # one — 1,089 "Foreign key violations found in your fixture data" errors that,
  # once again, blame the fixtures for a privilege problem.
  test "detects when the role may not run the post-fixture foreign-key verification" do
    assert_not ReferentialIntegrityCheck.can_verify_foreign_keys?(FakeConnection.new(raise_on_alter: true))
  end

  test "detects when the role may run the post-fixture foreign-key verification" do
    assert ReferentialIntegrityCheck.can_verify_foreign_keys?(FakeConnection.new(raise_on_alter: false))
  end

  test "the live test connection agrees with the fixture verification setting in force" do
    can_verify = ReferentialIntegrityCheck.can_verify_foreign_keys?(ActiveRecord::Base.lease_connection)

    assert_equal can_verify, ActiveRecord.verify_foreign_keys_for_fixtures,
      "verify_foreign_keys_for_fixtures must be off exactly when this role cannot perform it"
  end

  test "the live test connection can disable referential integrity" do
    assert_nil ReferentialIntegrityCheck.failure_message(ActiveRecord::Base.lease_connection)
  end

  # The message tells developers the narrow GRANT is enough. It only is because
  # of the adapter patch below it — stock Rails issues ALTER TABLE ... DISABLE
  # TRIGGER ALL and never touches session_replication_role, so without the patch
  # that advice would be wrong.
  test "the adapter is patched to honour session_replication_role" do
    assert_includes(
      ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.ancestors,
      ReferentialIntegrityCheck::ViaSessionReplicationRole
    )
  end

  test "disable_referential_integrity actually defers foreign keys on the live connection" do
    connection = ActiveRecord::Base.lease_connection
    dangling_user_id = ActiveRecord::FixtureSet.identify(:definitely_not_a_real_user)

    connection.transaction(requires_new: true) do
      connection.disable_referential_integrity do
        connection.execute(<<~SQL)
          INSERT INTO addresses (user_id, nickname, recipient_name, line1, city, postcode, country, created_at, updated_at)
          VALUES (#{dangling_user_id}, 'probe', 'probe', 'x', 'y', 'Z1 1AA', 'GB', now(), now())
        SQL
      end
      raise ActiveRecord::Rollback
    end

    assert_equal 0, Address.where(user_id: dangling_user_id).count
  end
end
