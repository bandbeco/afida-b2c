require "test_helper"

# The redirect and the webhook can both observe an order whose effects are
# still unrecorded. The row lock must let exactly one of them send. This
# file turns transactional tests off so the two threads can see the row.
class Checkout::CompletionRaceTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  include StripeTestHelper
  include ActiveJob::TestHelper
  include ActionMailer::TestHelper

  setup do
    clear_enqueued_jobs
    Sentry.stubs(:capture_exception)
    Sentry.stubs(:capture_message)
    Ga4MeasurementProtocolService.stubs(:track_purchase)
  end

  test "concurrent redirect and webhook run effects once" do
    cart = Cart.create!
    cart.cart_items.create!(product: products(:one), quantity: 1, price: 10.00)
    session = stub_stripe_session_retrieve(
      customer_email: "buyer@example.com",
      metadata: { cart_id: cart.id.to_s }
    )
    order = Checkout::Completion.complete(session.id, browser_present: true).order
    # A crash after the commit, before the marker. Both channels now see it.
    order.update_columns(effects_completed_at: nil)
    clear_enqueued_jobs

    entered = []
    mutex = Mutex.new
    original = Checkout::CompletionEffects.instance_method(:run)
    Checkout::CompletionEffects.define_method(:run) do
      first = false
      mutex.synchronize do
        entered << Thread.current.object_id
        first = entered.size == 1
      end
      # Hold the row lock long enough that the other channel is waiting on
      # it. If the lock were missing, that channel would enter run too.
      sleep 0.3 if first
      original.bind_call(self)
    end

    placed = Queue.new
    collector = Object.new
    collector.define_singleton_method(:emit) do |event|
      placed << event if event[:name] == "order.placed"
    end
    Rails.event.subscribe(collector)

    errors = Queue.new
    threads = [ true, false ].map do |browser_present|
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          ActiveRecord::Base.connection.execute("SET lock_timeout = '5s'")
          Checkout::Completion.complete(session.id, browser_present: browser_present)
        end
      rescue StandardError => e
        errors << e
      end
    end

    assert_enqueued_emails 2 do
      threads.each { |thread| assert thread.join(10), "completion thread hung" }
    end

    failures = Array.new(errors.size) { errors.pop }
    assert_empty failures, failures.map { |e|
      "#{e.class}: #{e.message}\n#{e.backtrace&.first(12)&.join("\n")}"
    }.join("\n---\n")
    assert_equal 1, entered.size
    assert_equal 1, placed.size
    assert_not_nil order.reload.effects_completed_at
    assert_enqueued_with(job: TelegramOrderNotificationJob, args: [ order.id ])
  ensure
    Rails.event.unsubscribe(collector) if defined?(collector) && collector
    Checkout::CompletionEffects.define_method(:run, original) if defined?(original) && original
    if defined?(session) && session
      Order.where(stripe_session_id: session.id).find_each do |row|
        row.order_items.delete_all
        row.delete
      end
    end
    if defined?(cart) && cart
      CartItem.where(cart_id: cart.id).delete_all
      Cart.where(id: cart.id).delete_all
    end
  end
end
