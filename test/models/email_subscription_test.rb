require "test_helper"

class EmailSubscriptionTest < ActiveSupport::TestCase
  # =============================================================================
  # T006: Validation Tests
  # =============================================================================

  test "valid with all required attributes" do
    subscription = EmailSubscription.new(email: "new@example.com")
    assert subscription.valid?
  end

  test "requires email" do
    subscription = EmailSubscription.new(email: nil)
    assert_not subscription.valid?
    assert_includes subscription.errors[:email], "can't be blank"
  end

  test "validates email format" do
    subscription = EmailSubscription.new(email: "invalid-email")
    assert_not subscription.valid?
    assert_includes subscription.errors[:email], "is invalid"
  end

  test "validates email uniqueness case-insensitively" do
    EmailSubscription.create!(email: "test@example.com")

    duplicate = EmailSubscription.new(email: "TEST@example.com")
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:email], "has already been taken"
  end

  test "normalizes email to lowercase and strips whitespace" do
    subscription = EmailSubscription.create!(email: "  TEST@EXAMPLE.COM  ")
    assert_equal "test@example.com", subscription.email
  end

  test "source defaults to cart_discount" do
    subscription = EmailSubscription.create!(email: "new@example.com")
    assert_equal "cart_discount", subscription.source
  end

  test "source can be overridden" do
    subscription = EmailSubscription.create!(email: "new@example.com", source: "footer")
    assert_equal "footer", subscription.source
  end

  # =============================================================================
  # T007: Eligibility Tests
  # =============================================================================

  test "eligible_for_discount? returns true for new email without orders" do
    assert EmailSubscription.eligible_for_discount?("brand-new@example.com")
  end

  test "eligible_for_discount? returns false for email already subscribed" do
    # Uses fixture: email_subscriptions(:claimed_discount) has email "claimed@example.com"
    assert_not EmailSubscription.eligible_for_discount?("claimed@example.com")
  end

  test "eligible_for_discount? returns false for email with previous orders" do
    # Uses fixture: orders(:one) has email "user1@example.com"
    assert_not EmailSubscription.eligible_for_discount?("user1@example.com")
  end

  test "eligible_for_discount? is case-insensitive" do
    assert_not EmailSubscription.eligible_for_discount?("CLAIMED@EXAMPLE.COM")
    assert_not EmailSubscription.eligible_for_discount?("USER1@EXAMPLE.COM")
  end

  test "eligible_for_discount? handles nil email" do
    assert_not EmailSubscription.eligible_for_discount?(nil)
  end

  test "eligible_for_discount? handles blank email" do
    assert_not EmailSubscription.eligible_for_discount?("")
    assert_not EmailSubscription.eligible_for_discount?("   ")
  end
end
