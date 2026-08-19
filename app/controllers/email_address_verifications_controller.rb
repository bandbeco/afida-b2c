class EmailAddressVerificationsController < ApplicationController
  include SendsVerificationEmail

  def show
    @user = User.find_by_email_address_verification_token!(params[:token])

    # Check if already verified before updating
    was_verified = @user.email_address_verified?
    @user.verify_email_address!

    # Send welcome email only if this is the first verification
    RegistrationMailer.welcome(@user).deliver_later unless was_verified

    redirect_to root_path, notice: "Your email address has been verified successfully. Welcome to Afida!", status: :see_other
  rescue ActiveSupport::MessageVerifier::InvalidSignature
    redirect_to root_path, notice: "Email confirmation link is invalid or has expired.", status: :unprocessable_entity
  end

  # Resending is the cheapest way to make this app send mail: it needs no new account,
  # just one session and a loop. VerificationEmailThrottle is what stops that, and it
  # is keyed on the user rather than the IP so rotating addresses does not reset it.
  def create
    if deliver_verification_email(Current.user)
      redirect_to root_path, notice: "Verification email sent. Please check your inbox."
    else
      redirect_to root_path, alert: "We've sent several verification emails recently. Please check your inbox and spam folder, then try again later."
    end
  end
end
