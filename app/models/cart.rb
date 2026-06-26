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
# - Shipping is previewed the same way checkout charges it: free at/above the
#   free-shipping threshold, otherwise STANDARD_COST. VAT is levied on
#   subtotal + shipping (UK VAT applies to delivery), so the preview's VAT and
#   total match what Stripe charges. An empty cart ships nothing and stays at 0.
# - An optional welcome discount (the rate injected by the controller from the
#   session coupon) is a plain Stripe percent_off coupon with no applies_to
#   restriction, so it reduces the WHOLE order: subtotal AND the taxed shipping
#   line. It lowers the VAT base and the total to match the Stripe charge, but never
#   the free-shipping decision (which keys off the gross subtotal).
# - Final total = (subtotal + shipping - discount) + VAT
#
# Usage:
#   Current.cart              # Access current cart (guest or user)
#   cart.items_count          # Total quantity of all items
#   cart.subtotal_amount      # Sum before VAT
#   cart.discount_amount      # Welcome discount on subtotal + shipping (0 when none)
#   cart.shipping_amount      # Charged shipping (0 when free, nil when empty)
#   cart.vat_amount           # 20% VAT on (subtotal + shipping - discount)
#   cart.total_amount         # Final total with discount, shipping and VAT
#
class Cart < ApplicationRecord
  SAMPLE_LIMIT = 5

  belongs_to :user, optional: true

  has_many :cart_items, dependent: :destroy
  has_many :products, through: :cart_items

  # The active discount as a fraction of the subtotal (e.g. 0.10 for the welcome
  # coupon). The coupon code lives in the session, not on the cart, so the
  # controller injects the rate; it defaults to 0 (no discount). Assigning it
  # clears the memoized totals so vat_amount/total_amount pick the discount up.
  attr_reader :discount_rate

  def discount_rate=(rate)
    @discount_rate = rate
    @cart_totals = nil
  end

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

  # The welcome discount in money: the rate applied to the whole order
  # (subtotal + shipping), matching the plain Stripe percent_off coupon (no
  # applies_to restriction). Zero when no discount is active. Delegates to
  # OrderTotals so the cart preview's discount line, VAT and total share one formula.
  def discount_amount
    cart_totals.discount
  end

  # Shipping the cart will be charged at checkout: 0 at/above the free-shipping
  # threshold, STANDARD_COST below it, and nil for an empty cart (nothing to
  # ship). Delegates to OrderTotals so this mirrors SessionBuilder's rule exactly.
  def shipping_amount
    cart_totals.shipping
  end

  # Calculate VAT at UK rate (20%) on subtotal + shipping. Delegates to
  # OrderTotals, the single home for the order-totals formula. The cart takes the
  # :charged stance so VAT and total match the Stripe charge (which taxes the
  # delivery line). An empty cart falls back to :deferred and so carries no VAT.
  def vat_amount
    cart_totals.vat
  end

  # Final total including shipping and VAT, matching what Stripe charges.
  def total_amount
    cart_totals.total
  end

  # Check if this is a guest cart (not associated with a user)
  def guest_cart?
    user.blank?
  end

  # Clear memoized values when cart items change
  # Call this after adding/updating/removing cart items.
  #
  # @discount_rate is deliberately NOT reset: it is injected by the controller
  # from the session coupon, not loaded from the DB, so a reload (a DB refresh)
  # can't change it. Clearing it here wiped the active welcome discount whenever
  # the CartItem sample-limit validator calls cart.reload mid-request, making the
  # discount vanish from the Turbo Stream cart preview. @cart_totals is still
  # cleared, so totals recompute against the preserved rate.
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
  # each recompute. :charged once the cart has items, so the previewed shipping,
  # VAT and total match the Stripe charge; :deferred for an empty cart, which has
  # nothing to ship and so shows no shipping line (and a £0 total).
  def cart_totals
    # ||= wraps the whole body so the cart_items.empty? query only fires on the
    # first call per request; later calls (this backs four public methods) reuse
    # the memoized result.
    @cart_totals ||= begin
      stance = cart_items.empty? ? :deferred : :charged
      OrderTotals.for(subtotal_amount, shipping: stance, discount_rate: discount_rate || 0)
    end
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
