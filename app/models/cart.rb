# Shopping cart for storing items before checkout
#
# Supports both guest and authenticated user carts:
# - Guest carts: user_id is nil, tracked by cookie session
# - User carts: associated with a User record
#
# On login, guest cart items are merged into the user's cart
#
# VAT calculation:
# - UK VAT rate of 20% (VAT_RATE = 0.2)
# - VAT calculated on subtotal (sum of all cart items)
# - Final total = subtotal + VAT
#
# Usage:
#   Current.cart              # Access current cart (guest or user)
#   cart.items_count          # Total quantity of all items
#   cart.subtotal_amount      # Sum before VAT
#   cart.vat_amount           # 20% VAT on subtotal
#   cart.total_amount         # Final total with VAT
#
class Cart < ApplicationRecord
  SAMPLE_LIMIT = 5

  belongs_to :user, optional: true

  has_many :cart_items, dependent: :destroy
  has_many :products, through: :cart_items

  # Total quantity of all items in cart (sum of quantities, not distinct items)
  # e.g., 4 of the same SKU = 4, not 1
  # Memoized to prevent repeated database calls within same request
  def items_count
    @items_count ||= cart_items.sum(:quantity)
  end

  # Cart badge count: number of distinct cart entries
  # Each product in cart = 1, regardless of quantity or product type
  # e.g., 2 packs napkins + 1000 branded cups = 2
  def line_items_count
    @line_items_count ||= cart_items.count
  end

  # Sum of all cart item subtotals (before VAT)
  # For standard products with pack pricing: sums calculated pack quantities
  # For configured/branded products: sums unit price * quantity
  # Uses Ruby-level calculation to leverage CartItem#subtotal_amount logic
  # Memoized to prevent repeated calculations within same request
  def subtotal_amount
    @subtotal_amount ||= cart_items.includes(:product).sum(&:subtotal_amount)
  end

  # Calculate VAT at UK rate (20%)
  # Delegates to OrderTotals, the single home for the order-totals formula. The
  # cart takes the :deferred shipping stance: shipping is added later at checkout
  # via Stripe, so it carries no shipping line here.
  def vat_amount
    cart_totals.vat
  end

  # Final total including VAT (no shipping; see vat_amount).
  # Note: Shipping cost is added separately at checkout via Stripe.
  def total_amount
    cart_totals.total
  end

  # Check if this is a guest cart (not associated with a user)
  def guest_cart?
    user.blank?
  end

  # Clear memoized values when cart items change
  # Call this after adding/updating/removing cart items
  def reload(*)
    @items_count = nil
    @line_items_count = nil
    @subtotal_amount = nil
    @cart_totals = nil
    @sample_product_ids = nil
    @regular_product_ids = nil
    super
  end

  # Sample tracking methods
  # Samples are identified by is_sample = true flag set at creation time

  # Returns cart items that are samples (is_sample = true)
  def sample_items
    cart_items.samples
  end

  # Returns count of sample items in cart
  def sample_count
    sample_items.count
  end

  # Returns product IDs of samples in cart (memoized to prevent N+1)
  def sample_product_ids
    @sample_product_ids ||= sample_items.pluck(:product_id)
  end

  # Returns product IDs of regular (non-sample) items in cart (memoized)
  def regular_product_ids
    @regular_product_ids ||= cart_items.non_samples.pluck(:product_id)
  end

  # Returns count of samples in a specific category
  def sample_count_for_category(category)
    sample_items.joins(:product)
                .where(products: { category_id: category.id })
                .count
  end

  # Returns true if cart contains only sample items (no paid products)
  def only_samples?
    cart_items.any? && cart_items.non_samples.none?
  end

  # Returns true if cart has reached the sample limit
  def at_sample_limit?
    sample_count >= SAMPLE_LIMIT
  end

  # Signed, expiring token for cross-device cart recovery (abandoned-cart emails).
  # Mirrors Order#signed_access_token; a distinct purpose ("cart_recovery") means
  # an order access token can never be replayed as a cart recovery token.
  def signed_recovery_token
    to_sgid(expires_in: 30.days, for: "cart_recovery").to_s
  end

  # Absolute URL that re-binds the recipient's session to this cart (see
  # CartsController#resume). Passes the Action Mailer host explicitly so the URL
  # resolves whether built in a request or not; the route helper also falls back
  # to routes.default_url_options if the mailer host is absent.
  def recovery_url
    Rails.application.routes.url_helpers.resume_cart_url(token: signed_recovery_token, **url_options)
  end

  # Resolves a cart from a recovery token, or nil if the token is missing,
  # malformed, expired, signed for another purpose, or the cart no longer exists.
  def self.find_by_recovery_token(token)
    GlobalID::Locator.locate_signed(token, for: "cart_recovery")
  rescue ActiveRecord::RecordNotFound, ActiveSupport::MessageVerifier::InvalidSignature
    nil
  end

  private

  # The cart's order totals, computed once per request. Memoized like
  # subtotal_amount (and cleared in reload) so vat_amount and total_amount don't
  # each recompute. :deferred — the cart never shows a shipping line.
  def cart_totals
    @cart_totals ||= OrderTotals.for(subtotal_amount, shipping: :deferred)
  end

  # Action Mailer's host, configured in every environment. recovery_url runs
  # inline in KlaviyoSubscriber (a synchronous Rails.event subscriber), so a nil
  # here would propagate into the emitting request; in practice resume_cart_url
  # falls back to routes.default_url_options (also set in every environment), so
  # a missing mailer host degrades to that host rather than a hostless URL.
  def url_options
    Rails.application.config.action_mailer.default_url_options
  end
end
