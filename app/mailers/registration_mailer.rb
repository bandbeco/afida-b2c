class RegistrationMailer < ApplicationMailer
  default bcc: "hello@afida.com"

  def verify_email_address(user)
    # Emergency kill switch. Bots have fed strangers' addresses through /signup
    # (subscription bombing), and every registration mails its victim from our
    # domain. Set in deploy.yml until the signup hardening lands; returning
    # before mail() yields a NullMail, which ActionMailer silently discards.
    # Scoped to this action only: order and password mail are unaffected.
    return if ENV["SUPPRESS_VERIFICATION_EMAILS"].present?

    @user = user

    mail(
      to: user.email_address,
      subject: "Verify your email address"
    )
  end

  def welcome(user)
    @user = user

    mail(
      to: user.email_address,
      subject: "Welcome to Afida!"
    )
  end
end
