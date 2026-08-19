require "test_helper"

class RegistrationsControllerTest < ActionDispatch::IntegrationTest
  include ActionMailer::TestHelper

  # The notice a real signup gets. The honeypot path must be indistinguishable from
  # it, so a bot cannot probe which field gave it away.
  SIGNUP_NOTICE = "Please check your email for verification instructions."

  test "signup form renders the honeypot field" do
    get new_registration_path

    assert_response :success
    assert_select "input[name=?]", "user[#{RegistrationsController::HONEYPOT_FIELD}]"
  end

  test "genuine signup creates the user and sends one verification email" do
    assert_difference "User.count", 1 do
      assert_enqueued_emails 1 do
        post registration_path, params: {
          user: { email_address: "genuine@example.com", password: "password123", password_confirmation: "password123" }
        }
      end
    end

    assert_redirected_to root_path
    assert_equal SIGNUP_NOTICE, flash[:notice]
  end

  test "signup with the honeypot filled creates no user" do
    assert_no_difference "User.count" do
      post registration_path, params: {
        user: {
          email_address: "bot@example.com",
          password: "password123",
          password_confirmation: "password123",
          RegistrationsController::HONEYPOT_FIELD => "http://spam.example"
        }
      }
    end
  end

  test "signup with the honeypot filled sends no email" do
    assert_no_enqueued_emails do
      post registration_path, params: {
        user: {
          email_address: "bot@example.com",
          password: "password123",
          password_confirmation: "password123",
          RegistrationsController::HONEYPOT_FIELD => "http://spam.example"
        }
      }
    end
  end

  # Silence, not an error page: a bot that can tell it was caught will simply stop
  # filling the field.
  test "a caught bot gets the same response a real signup gets" do
    post registration_path, params: {
      user: {
        email_address: "bot@example.com",
        password: "password123",
        password_confirmation: "password123",
        RegistrationsController::HONEYPOT_FIELD => "http://spam.example"
      }
    }

    assert_redirected_to root_path
    assert_equal SIGNUP_NOTICE, flash[:notice]
  end

  test "a caught bot is not signed in" do
    post registration_path, params: {
      user: {
        email_address: "bot@example.com",
        password: "password123",
        password_confirmation: "password123",
        RegistrationsController::HONEYPOT_FIELD => "http://spam.example"
      }
    }

    assert_nil cookies[:session_id].presence
  end

  test "an empty honeypot field does not block a genuine signup" do
    assert_difference "User.count", 1 do
      post registration_path, params: {
        user: {
          email_address: "genuine@example.com",
          password: "password123",
          password_confirmation: "password123",
          RegistrationsController::HONEYPOT_FIELD => ""
        }
      }
    end
  end

  # The account is created and usable either way (nothing in the app gates on
  # email_address_verified), but telling someone to check an inbox we never sent to
  # sends them looking for a message that does not exist.
  test "a throttled verification email still creates the account" do
    VerificationEmailThrottle.stubs(:allow?).returns(false)

    assert_difference "User.count", 1 do
      post registration_path, params: {
        user: { email_address: "throttled@example.com", password: "password123", password_confirmation: "password123" }
      }
    end
  end

  test "a throttled verification email is not silently reported as sent" do
    VerificationEmailThrottle.stubs(:allow?).returns(false)

    assert_no_enqueued_emails do
      post registration_path, params: {
        user: { email_address: "throttled@example.com", password: "password123", password_confirmation: "password123" }
      }
    end

    assert_not_equal SIGNUP_NOTICE, flash[:notice]
  end

  # Junk-shaped bodies are exactly what automated traffic sends. Reading the honeypot
  # out of a scalar :user must not turn that into a 500 on an unauthenticated endpoint.
  test "a scalar user param is refused without raising" do
    post registration_path, params: { user: "not-a-hash" }

    assert_response :bad_request
  end
end
