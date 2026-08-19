# The single choke point for verification mail. Both the signup flow and the resend
# endpoint go through here so neither can outrun VerificationEmailThrottle.
module SendsVerificationEmail
  extend ActiveSupport::Concern

  private

  # Returns whether the email was actually handed to the mailer. A refusal is logged
  # rather than raised: the caller decides what the visitor is told, and a suppressed
  # send is an operational event, not a request error.
  def deliver_verification_email(user)
    unless VerificationEmailThrottle.allow?(user)
      Rails.logger.warn(
        "[verification] send suppressed by throttle user=#{user.id} " \
        "ip=#{request.remote_ip} global_spent=#{VerificationEmailThrottle.global_spent}"
      )
      return false
    end

    RegistrationMailer.verify_email_address(user).deliver_later
    true
  end
end
