class EmailSubscriptionsController < ApplicationController
  allow_unauthenticated_access

  def create
    @email = email_param&.strip&.downcase

    # Check eligibility before creating
    if @email.blank?
      render_validation_error
      return
    end

    unless valid_email_format?(@email)
      render_validation_error
      return
    end

    # Check if email has already claimed the discount
    if EmailSubscription.discount_already_claimed?(@email)
      render_already_claimed
      return
    end

    # Check if email has previous orders
    if Order.exists?(email: @email)
      render_not_eligible
      return
    end

    # Find existing subscription (newsletter-only) or build new one
    @subscription = EmailSubscription.find_or_initialize_by(email: @email)
    @subscription.assign_attributes(
      discount_claimed_at: Time.current,
      source: @subscription.new_record? ? "cart_discount" : @subscription.source
    )

    if @subscription.save
      # Store discount code in session (only if not already present)
      session[:discount_code] ||= welcome_discount_code
      render_success
    else
      render_validation_error
    end
  end

  private

  def email_param
    # Try direct param first, then nested under email_subscription
    params[:email] || params.dig(:email_subscription, :email)
  end

  def valid_email_format?(email)
    email.match?(URI::MailTo::EMAIL_REGEXP)
  end

  def welcome_discount_code
    Rails.application.credentials.dig(:stripe, :welcome_coupon) || "WELCOME5"
  end

  def render_success
    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace(
          "discount-signup",
          partial: "email_subscriptions/success",
          locals: { cart: Current.cart }
        )
      end
      format.html { redirect_to cart_path, notice: "Discount applied!" }
    end
  end

  def render_already_claimed
    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace(
          "discount-signup",
          partial: "email_subscriptions/already_claimed"
        )
      end
      format.html { redirect_to cart_path, alert: "You've already claimed this discount." }
    end
  end

  def render_not_eligible
    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace(
          "discount-signup",
          partial: "email_subscriptions/not_eligible"
        )
      end
      format.html { redirect_to cart_path, alert: "This discount is for new customers only." }
    end
  end

  def render_validation_error
    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace(
          "discount-signup",
          partial: "email_subscriptions/cart_signup_form",
          locals: { error: "Please enter a valid email address" }
        ), status: :unprocessable_entity
      end
      format.html { redirect_to cart_path, alert: "Please enter a valid email address." }
    end
  end
end
