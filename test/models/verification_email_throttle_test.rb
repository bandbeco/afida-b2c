require "test_helper"

class VerificationEmailThrottleTest < ActiveSupport::TestCase
  setup do
    @original_cache = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
    @user = users(:one)
    @other_user = users(:two)
  end

  teardown do
    Rails.cache = @original_cache
  end

  test "allows sends up to the per-user hourly limit" do
    VerificationEmailThrottle.stubs(:per_user_hourly_limit).returns(3)

    3.times do |n|
      assert VerificationEmailThrottle.allow?(@user), "send #{n + 1} should be allowed"
    end
  end

  test "refuses the send that exceeds the per-user hourly limit" do
    VerificationEmailThrottle.stubs(:per_user_hourly_limit).returns(3)

    3.times { VerificationEmailThrottle.allow?(@user) }

    assert_not VerificationEmailThrottle.allow?(@user)
  end

  test "budgets are per user, so one user cannot exhaust another's" do
    VerificationEmailThrottle.stubs(:per_user_hourly_limit).returns(2)

    2.times { VerificationEmailThrottle.allow?(@user) }
    assert_not VerificationEmailThrottle.allow?(@user)

    assert VerificationEmailThrottle.allow?(@other_user)
  end

  # The blast-radius cap. A distributed attack presents many different users, so the
  # per-user budget never trips; this is the only bound on how much mail can leave
  # the domain in an hour.
  test "refuses a fresh user once the global hourly limit is spent" do
    VerificationEmailThrottle.stubs(:per_user_hourly_limit).returns(100)
    VerificationEmailThrottle.stubs(:global_hourly_limit).returns(2)

    2.times { assert VerificationEmailThrottle.allow?(@user) }

    assert_not VerificationEmailThrottle.allow?(@other_user)
  end

  # A refused per-user send must not also consume global budget, or a single looping
  # attacker would spend the whole domain's hourly allowance on its own rejections.
  test "a refused per-user send does not consume global budget" do
    VerificationEmailThrottle.stubs(:per_user_hourly_limit).returns(1)
    VerificationEmailThrottle.stubs(:global_hourly_limit).returns(5)

    VerificationEmailThrottle.allow?(@user)
    3.times { VerificationEmailThrottle.allow?(@user) }

    assert_equal 1, VerificationEmailThrottle.global_spent
  end

  # The mirror of the test above. A user turned away because the domain-wide ceiling is
  # spent has not caused any mail to be sent, so charging their small hourly allowance
  # for it would keep them locked out after the global window clears.
  test "a send refused by the global ceiling does not consume the user's budget" do
    VerificationEmailThrottle.stubs(:per_user_hourly_limit).returns(3)
    VerificationEmailThrottle.stubs(:global_hourly_limit).returns(1)

    VerificationEmailThrottle.allow?(@other_user)

    assert_not VerificationEmailThrottle.allow?(@user)
    assert_equal 0, VerificationEmailThrottle.user_spent(@user)
  end

  # Matches Rails' own rate_limit semantics: when the cache cannot count
  # (increment returns nil), requests are allowed rather than everyone locked out.
  test "fails open when the cache store cannot count" do
    Rails.cache = ActiveSupport::Cache::NullStore.new

    assert VerificationEmailThrottle.allow?(@user)
  end
end
