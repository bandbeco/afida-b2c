# Mints the Stripe promotion codes The Afida Stack pays out in. Every code is
# unique and single-use, so a screenshot of one is worthless on coupon sites;
# each expires with the month, matching the game's "this month only" copy. The
# two coupons the codes draw on are created in Stripe on first use.
module Game
  class PromoCodes
    # Consonants and unambiguous digits only: no 0/O, 1/I/L, and no vowels so
    # six random characters can't spell anything.
    CODE_ALPHABET = %w[C D F H J K M N P R T V W X Y 3 4 6 7 9].freeze
    PERCENT_OFF = 5
    # A forged-but-plausible drop log is indistinguishable from a real one, so
    # scripted minting can't be made impossible — only unprofitable. Coupons
    # are scoped to the month and capped, putting a hard ceiling on what even
    # a distributed scraper could give away.
    MONTHLY_REDEMPTION_CAP = 200

    # Stripe caps coupon names at 40 characters, and the month suffix in
    # coupon_id adds 15 — keep these short.
    WIN = { coupon: "afida-stack-win", prefix: "STACK", name: "Afida Stack win" }.freeze
    REFERRAL = { coupon: "afida-stack-mate", prefix: "MATE", name: "Afida Stack invite" }.freeze

    def self.mint_win_code = mint(WIN)
    def self.mint_referral_code = mint(REFERRAL)

    def self.mint(kind)
      Stripe::PromotionCode.create(
        promotion: { type: "coupon", coupon: coupon_id(kind) },
        code: kind[:prefix] + Array.new(6) { CODE_ALPHABET.sample }.join,
        max_redemptions: 1,
        expires_at: Time.current.end_of_month.to_i
      ).code
    end

    # True when Stripe knows an active promotion code by this exact string.
    def self.active?(code)
      Stripe::PromotionCode.list(code: code, active: true, limit: 1).data.any?
    end

    def self.coupon_id(kind)
      id = "#{kind[:coupon]}-#{Date.current.strftime('%Y-%m')}"
      Stripe::Coupon.retrieve(id).id
    rescue Stripe::InvalidRequestError
      Stripe::Coupon.create(
        id: id,
        percent_off: PERCENT_OFF,
        duration: "once",
        max_redemptions: MONTHLY_REDEMPTION_CAP,
        name: "#{kind[:name]} (#{Date.current.strftime('%B %Y')})"
      ).id
    end
  end
end
