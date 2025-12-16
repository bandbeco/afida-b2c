class SessionsController < ApplicationController
  allow_unauthenticated_access only: %i[ new create modal ]
  rate_limit to: 10, within: 3.minutes, only: :create, with: -> { redirect_to new_session_url, alert: "Try again later." }

  def new
  end

  # GET /signin/modal - Sign-in form for modal display
  def modal
    @return_to = params[:return_to]
  end

  def create
    if user = User.authenticate_by(params.permit(:email_address, :password))
      start_new_session_for user
      # Prioritize return_to param (from modal) over session (from require_authentication)
      redirect_url = params[:return_to].presence || after_authentication_url
      redirect_to redirect_url
    else
      redirect_to new_session_path, alert: "Try another email address or password."
    end
  end

  def destroy
    terminate_session
    redirect_to root_path, notice: "You have been logged out."
  end
end
