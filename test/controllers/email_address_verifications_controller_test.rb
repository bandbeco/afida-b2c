require "test_helper"

class EmailAddressVerificationsControllerTest < ActionDispatch::IntegrationTest
  include ActionMailer::TestHelper

  setup do
    @original_cache = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
    @user = users(:one)
  end

  teardown do
    Rails.cache = @original_cache
  end

  test "resend requires authentication" do
    assert_no_enqueued_emails do
      post email_address_verifications_path
    end

    assert_redirected_to new_session_path
  end

  test "resend sends one verification email to the signed-in user" do
    sign_in_as(@user)

    assert_enqueued_emails 1 do
      post email_address_verifications_path
    end
  end

  # The amplifier: before this throttle, one authenticated session could loop this
  # endpoint without bound, each iteration sending mail from our domain.
  test "resend stops sending once the per-user hourly budget is spent" do
    VerificationEmailThrottle.stubs(:per_user_hourly_limit).returns(2)
    sign_in_as(@user)

    2.times { post email_address_verifications_path }

    assert_no_enqueued_emails do
      post email_address_verifications_path
    end
  end

  test "a throttled resend tells the user to wait rather than failing silently" do
    VerificationEmailThrottle.stubs(:per_user_hourly_limit).returns(1)
    sign_in_as(@user)

    post email_address_verifications_path
    post email_address_verifications_path

    assert_not_nil flash[:alert]
  end

  private

  def sign_in_as(user)
    post session_url, params: { email_address: user.email_address, password: "password" }
  end
end
