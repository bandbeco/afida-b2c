namespace :orders do
  desc "Backfill orders.discount_code from Stripe for discounted orders that recorded none (APPLY=1 to write)"
  task backfill_discount_code: :environment do
    apply = ENV["APPLY"] == "1"

    # Orders that carry a discount but no code: the signature of the attribution bug
    # (total_details.breakdown was never expanded, so the promotion code was
    # unreadable). Stripe still holds the truth, so re-read it per session.
    scope = Order.where(discount_code: [ nil, "" ])
                 .where("discount_amount > 0")
                 .where.not(stripe_session_id: [ nil, "" ])
                 .order(:created_at)

    puts "Found #{scope.count} discounted orders with no recorded discount_code."
    puts(apply ? "APPLY — writing changes" : "DRY RUN — no writes (pass APPLY=1 to write)")
    puts

    resolved = 0
    unresolved = 0
    failed = 0

    scope.each do |order|
      session = Stripe::Checkout::Session.retrieve(
        id: order.stripe_session_id,
        expand: [ "total_details.breakdown" ]
      )
      code = Checkout::SessionDetails.promotion_code(session)

      if code.blank?
        # A discount applied as a bare coupon (no promotion code) has no
        # human-typed name to recover. Left alone rather than guessed at.
        unresolved += 1
        puts "  order #{order.id} #{order.created_at.to_date} #{order.email}: no promotion code on session, skipping"
        next
      end

      resolved += 1
      puts "  order #{order.id} #{order.created_at.to_date} #{order.email}: #{code} (disc #{order.discount_amount})"
      order.update_columns(discount_code: code) if apply
    rescue Stripe::StripeError => e
      failed += 1
      puts "  order #{order.id}: Stripe error, skipping (#{e.message})"
    end

    puts
    puts "resolved: #{resolved}, no code on session: #{unresolved}, stripe errors: #{failed}"
    puts "Re-run with APPLY=1 to persist." unless apply
  end
end
