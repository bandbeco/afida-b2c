# frozen_string_literal: true

require "test_helper"

class MargotResearchJobTest < ActiveJob::TestCase
  setup do
    @order = orders(:one)
  end

  test "requests research for a new customer's order" do
    @order.update_columns(user_id: nil, email: "first-order@example.com")
    MargotNotifier.expects(:request_research).with { |order| order.id == @order.id }

    MargotResearchJob.perform_now(@order.id)
  end

  test "does not request research for a returning customer" do
    assert_not @order.new_customer?, "fixture should be a returning customer"
    MargotNotifier.expects(:request_research).never

    MargotResearchJob.perform_now(@order.id)
  end

  test "does nothing when the order does not exist" do
    MargotNotifier.expects(:request_research).never

    MargotResearchJob.perform_now(-1)
  end
end
