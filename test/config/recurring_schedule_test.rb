require "test_helper"
require "fugit"

# config/recurring.yml only runs in production, so nothing else exercises it.
# This is the only guard against a typo'd class name or schedule shipping.
class RecurringScheduleTest < ActiveSupport::TestCase
  RECURRING = YAML.load_file(Rails.root.join("config/recurring.yml")).freeze

  test "every entry names a real job class and a parseable schedule" do
    RECURRING.fetch("production").each do |name, config|
      assert_nothing_raised { config.fetch("class").constantize }
      assert_not_nil Fugit.parse(config.fetch("schedule")), "#{name}: schedule does not parse"
    end
  end

  test "the weekly lead discovery job is scheduled" do
    config = RECURRING.fetch("production").fetch("discover_leads", nil)

    assert_not_nil config, "discover_leads entry missing from config/recurring.yml"
    assert_equal "LeadGen::DiscoverLeadsJob", config["class"]
  end
end
