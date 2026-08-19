require "test_helper"

class RegistrationMailerTest < ActionMailer::TestCase
  setup do
    @user = users(:one)
  end

  # verify_email_address tests
  test "verify_email_address sends email to user email address" do
    email = RegistrationMailer.verify_email_address(@user)

    assert_emails 1 do
      email.deliver_now
    end

    assert_equal [ @user.email_address ], email.to
  end

  test "verify_email_address has correct subject" do
    email = RegistrationMailer.verify_email_address(@user)

    assert_equal "Verify your email address", email.subject
  end

  test "verify_email_address includes BCC to hello email" do
    email = RegistrationMailer.verify_email_address(@user)

    assert_includes email.bcc, "hello@afida.com"
  end

  test "verify_email_address includes verification token" do
    email = RegistrationMailer.verify_email_address(@user)

    # Token should be generated and included
    assert_match /verify/, email.body.encoded.downcase
  end

  test "verify_email_address body includes verification link" do
    email = RegistrationMailer.verify_email_address(@user)

    # Email should have a verification link
    assert_match /email_address_verifications/, email.body.encoded
  end

  test "verify_email_address can be delivered" do
    assert_nothing_raised do
      RegistrationMailer.verify_email_address(@user).deliver_now
    end
  end

  test "verify_email_address has HTML content" do
    email = RegistrationMailer.verify_email_address(@user)

    assert_match /html/, email.content_type
  end

  # welcome tests
  test "welcome sends email to user email address" do
    email = RegistrationMailer.welcome(@user)

    assert_emails 1 do
      email.deliver_now
    end

    assert_equal [ @user.email_address ], email.to
  end

  test "welcome has correct subject" do
    email = RegistrationMailer.welcome(@user)

    assert_equal "Welcome to Afida!", email.subject
  end

  test "welcome includes BCC to hello email" do
    email = RegistrationMailer.welcome(@user)

    assert_includes email.bcc, "hello@afida.com"
  end

  test "welcome body includes welcome message" do
    email = RegistrationMailer.welcome(@user)

    assert_match /welcome/i, email.body.encoded
  end

  test "welcome can be delivered" do
    assert_nothing_raised do
      RegistrationMailer.welcome(@user).deliver_now
    end
  end

  test "welcome has HTML content" do
    email = RegistrationMailer.welcome(@user)

    assert_match /html/, email.content_type
  end

  # General mailer tests
  test "registration mailer uses correct from address" do
    email = RegistrationMailer.verify_email_address(@user)

    assert_not_nil email.from
    assert email.from.any?
  end

  test "verify_email_address and welcome use different subjects" do
    verify_email = RegistrationMailer.verify_email_address(@user)
    welcome_email = RegistrationMailer.welcome(@user)

    assert_not_equal verify_email.subject, welcome_email.subject
  end

  test "both mailer methods work with same user" do
    assert_nothing_raised do
      RegistrationMailer.verify_email_address(@user).deliver_now
      RegistrationMailer.welcome(@user).deliver_now
    end
  end

  # ===========================================================================
  # SUPPRESS_VERIFICATION_EMAILS kill switch
  # ===========================================================================
  # Emergency stop for the subscription-bombing pattern: bots feed victims'
  # addresses through /signup and every registration mails a stranger from our
  # domain. The switch suppresses only this mailer action; order confirmations
  # and password resets are untouched. See /runbooks/verification-email-throttling.md.

  test "verify_email_address sends nothing while the kill switch is set" do
    ENV["SUPPRESS_VERIFICATION_EMAILS"] = "true"

    assert_no_emails do
      RegistrationMailer.verify_email_address(@user).deliver_now
    end
  ensure
    ENV.delete("SUPPRESS_VERIFICATION_EMAILS")
  end

  test "verify_email_address delivers normally when the kill switch is unset" do
    assert_emails 1 do
      RegistrationMailer.verify_email_address(@user).deliver_now
    end
  end
end
