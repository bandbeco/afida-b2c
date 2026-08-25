# Start SimpleCov before loading any application code
require "simplecov"
SimpleCov.start "rails" do
  add_filter "/test/"
  add_filter "/config/"
  add_filter "/vendor/"

  add_group "Models", "app/models"
  add_group "Controllers", "app/controllers"
  add_group "Mailers", "app/mailers"
  add_group "Jobs", "app/jobs"
  add_group "Helpers", "app/helpers"
end

ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require "mocha/minitest"

# Load test support files
Dir[Rails.root.join("test/support/**/*.rb")].each { |f| require f }

# Fixtures cannot load unless this role may disable foreign-key checks. Without
# this, that shows up as thousands of identical foreign-key errors that name
# the wrong cause. Fail once, early, and say how to fix it.
if (message = ReferentialIntegrityCheck.failure_message(ActiveRecord::Base.lease_connection))
  abort(message)
end

# Rails re-validates every foreign key after loading fixtures, by writing to
# pg_catalog.pg_constraint. That is superuser-only and cannot be granted, so an
# unprivileged role has to go without the check rather than fail 1,089 times
# claiming the fixtures are invalid. CI runs as postgres and keeps it.
unless ReferentialIntegrityCheck.can_verify_foreign_keys?(ActiveRecord::Base.lease_connection)
  ActiveRecord.verify_foreign_keys_for_fixtures = false
  warn "NOTE: skipping post-fixture foreign-key verification (needs superuser). " \
       "See docs/runbooks/local-test-database.md."
end

module ActiveSupport
  class TestCase
    # Include N+1 query detection helpers
    include NPlusOneHelpers
    # Include fixture file upload helper for Active Storage tests
    include ActionDispatch::TestProcess::FixtureFile

    # Disable parallel tests for accurate SimpleCov coverage
    # parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Include event assertion helpers for Rails.event testing
    include EventTestHelper

    # Add more helper methods to be used by all tests here...
  end
end
