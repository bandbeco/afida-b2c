# Mints the Stripe promotion codes The Afida Stack pays out in. Every code is
# unique and single-use, so a screenshot of one is worthless on coupon sites;
# each expires with the month, matching the game's "this month only" copy. The
# two coupons the codes draw on are created in Stripe on first use.
module Game
  class PromoCodes
    # Consonants and unambiguous digits only: no 0/O, 1/I/L, and no vowels so
    # six random characters can't spell anything.
    CODE_ALPHABET = %w[C D F H J K M N P R T V W X Y 3 4 6 7 9].freeze
    AMOUNT_OFF_PENCE = 1_000
    # A forged-but-plausible drop log is indistinguishable from a real one, so
    # scripted minting can't be made impossible — only unprofitable. Coupons
    # are scoped to the month and capped, putting a hard ceiling on what even
    # a distributed scraper could give away.
    MONTHLY_REDEMPTION_CAP = 200
    # Matches the free-delivery threshold: the prize nudges a real stocking
    # order, not a £15 samples basket. Stripe checks this against the checkout
    # subtotal, where shipping rides as a line item — near-misses can squeak
    # through, which is fine.
    MINIMUM_ORDER_PENCE = 10_000

    # Stripe caps coupon names at 40 characters, and the month suffix in
    # coupon_id adds 15 — keep these short. New ids so we never retrieve the
    # old 5%-off coupons from earlier in the month.
    WIN = { coupon: "afida-stack-ten", prefix: "STACK", name: "Afida Stack £10" }.freeze
    REFERRAL = { coupon: "afida-stack-ref", prefix: "MATE", name: "Afida Stack invite" }.freeze

    def self.mint_win_code = mint(WIN)
    def self.mint_referral_code = mint(REFERRAL)

    def self.mint(kind)
      Stripe::PromotionCode.create(
        promotion: { type: "coupon", coupon: coupon_id(kind) },
        code: kind[:prefix] + Array.new(6) { CODE_ALPHABET.sample }.join,
        max_redemptions: 1,
        expires_at: Time.current.end_of_month.to_i,
        restrictions: { minimum_amount: MINIMUM_ORDER_PENCE, minimum_amount_currency: "gbp" }
      ).code
    end

    def self.coupon_id(kind)
      id = "#{kind[:coupon]}-#{Date.current.strftime('%Y-%m')}"
      Stripe::Coupon.retrieve(id).id
    rescue Stripe::InvalidRequestError
      Stripe::Coupon.create(
        id: id,
        amount_off: AMOUNT_OFF_PENCE,
        currency: "gbp",
        duration: "once",
        max_redemptions: MONTHLY_REDEMPTION_CAP,
        name: "#{kind[:name]} (#{Date.current.strftime('%B %Y')})"
      ).id
    end
  end
end
