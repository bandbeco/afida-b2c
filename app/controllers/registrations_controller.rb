class RegistrationsController < ApplicationController
  include SendsVerificationEmail

  # Bots fill every input they find. This one is hidden from people (see the
  # .honeypot-field rule in custom-styles.css) and left unlabelled in the model, so
  # anything arriving in it came from something that did not render the page.
  HONEYPOT_FIELD = :company_website

  # Shared by the real signup and by the honeypot refusal, which must be
  # indistinguishable from it.
  SIGNUP_NOTICE = "Please check your email for verification instructions."

  # If Authentication concern is not in ApplicationController, include it:
  # include Authentication
  # Or, if it's already in ApplicationController, ensure this controller allows unauthenticated access for new/create
  allow_unauthenticated_access only: [ :new, :create ] # Use this if Authentication concern's before_action :require_authentication is in ApplicationController

  # Declared ahead of the rate limit so caught bots are dropped without charging the
  # per-IP budget, which a real customer behind the same NAT may still need.
  before_action :discard_honeypot_submission, only: :create

  rate_limit to: 3, within: 1.hour, only: :create, with: -> { redirect_to new_registration_url, alert: "Too many registration attempts. Try again later." }

  def new
    @user = User.new
  end

  def create
    @user = User.new(user_params)

    if @user.save
      start_new_session_for @user
      deliver_verification_email(@user)

      redirect_to root_path, notice: SIGNUP_NOTICE
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def user_params
    params.expect(user: [ :email_address, :password, :password_confirmation ])
  end

  # Answers exactly as a successful signup would. Telling a bot which field gave it
  # away is all the feedback it needs to stop filling that field.
  def discard_honeypot_submission
    return if params.dig(:user, HONEYPOT_FIELD).blank?

    Rails.logger.warn(
      "[registrations] honeypot tripped ip=#{request.remote_ip} ua=#{request.user_agent.inspect}"
    )

    redirect_to root_path, notice: SIGNUP_NOTICE
  end
end
