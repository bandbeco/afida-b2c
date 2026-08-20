class RegistrationsController < ApplicationController
  include SendsVerificationEmail

  # Bots fill every input they find. This one is hidden from people (see the
  # .honeypot-field rule in custom-styles.css) and left unlabelled in the model, so
  # anything arriving in it came from something that did not render the page.
  #
  # The name is deliberately meaningless. Anything resembling company/website/url is
  # pattern-matched by password managers and browser profile autofill, several of which
  # ignore autocomplete="off"; a genuine customer whose manager filled it would be
  # dropped as silently as a bot.
  HONEYPOT_FIELD = :secondary_reference

  # Shared by the real signup and by the honeypot refusal, which must be
  # indistinguishable from it.
  SIGNUP_NOTICE = "Please check your email for verification instructions."

  # Nothing in the app gates on email_address_verified, so a suppressed verification
  # email leaves a working account — but pointing someone at an inbox we never sent to
  # sends them hunting for a message that does not exist.
  VERIFICATION_UNAVAILABLE_NOTICE =
    "Account created. We could not send your verification email just now, so please request a new one shortly."

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
      sent = deliver_verification_email(@user)

      redirect_to root_path, notice: sent ? SIGNUP_NOTICE : VERIFICATION_UNAVAILABLE_NOTICE
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
    # Not params.dig: Parameters#dig delegates to Hash#dig, so a scalar :user (which is
    # exactly the shape junk automated traffic sends) raises TypeError and turns an
    # unauthenticated endpoint into a 500. Let the malformed body fall through to
    # user_params, which refuses it as a 400.
    submitted = params[:user]
    return unless submitted.is_a?(ActionController::Parameters)
    return if submitted[HONEYPOT_FIELD].blank?

    Rails.logger.warn(
      "[registrations] honeypot tripped ip=#{request.remote_ip} ua=#{request.user_agent.inspect}"
    )

    redirect_to root_path, notice: SIGNUP_NOTICE
  end
end
