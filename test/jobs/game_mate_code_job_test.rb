require "test_helper"

class GameMateCodeJobTest < ActiveJob::TestCase
  include ActionMailer::TestHelper

  def order_attrs(email:, subtotal:)
    {
      email: email,
      stripe_session_id: "sess_#{SecureRandom.hex(8)}",
      status: "paid",
      subtotal_amount: subtotal,
      vat_amount: 20,
      shipping_amount: 5,
      total_amount: subtotal + 25,
      shipping_name: "A Cafe",
      shipping_address_line1: "1 High St",
      shipping_city: "London",
      shipping_postal_code: "SW1A 1AA",
      shipping_country: "GB"
    }
  end

  def referred_lead(referrer_email: "roastery@example.com")
    host = LeaderboardEntry.create!(name: "Roastery", score: 20,
      submitter_ip: "203.0.113.9", email: referrer_email)
    GameLead.capture(email: "invitee@example.com", source: "win", referrer: host)
    host
  end

  test "mints and emails a ten-pound code when a referred address places a first 100-pound order" do
    host = referred_lead
    order = Order.create!(order_attrs(email: "invitee@example.com", subtotal: 100))
    Stripe::Coupon.stubs(:retrieve).returns(stub(id: "afida-stack-ref"))
    Stripe::PromotionCode.stubs(:create).returns(stub(code: "MATEC4NHW6"))

    assert_enqueued_email_with GameMailer, :mate_code, args: [ "roastery@example.com", "MATEC4NHW6" ] do
      GameMateCodeJob.perform_now(order.id)
    end
    lead = GameLead.find_by(email: "invitee@example.com")
    assert lead.referrer_rewarded_at.present?
    assert_equal "MATEC4NHW6", lead.mate_promo_code
    assert_equal host, lead.referrer
  end

  test "a retry after the payout is claimed resends the stored code" do
    referred_lead
    order = Order.create!(order_attrs(email: "invitee@example.com", subtotal: 100))
    Stripe::Coupon.stubs(:retrieve).returns(stub(id: "afida-stack-ref"))
    Stripe::PromotionCode.stubs(:create).returns(stub(code: "MATEC4NHW6"))
    GameMateCodeJob.perform_now(order.id)

    Stripe::PromotionCode.stubs(:create).returns(stub(code: "MATEXXXXXX"))
    assert_enqueued_email_with GameMailer, :mate_code, args: [ "roastery@example.com", "MATEC4NHW6" ] do
      GameMateCodeJob.perform_now(order.id)
    end
  end

  test "a first order under 100 pounds pays nothing" do
    referred_lead
    order = Order.create!(order_attrs(email: "invitee@example.com", subtotal: 40))

    assert_no_enqueued_emails do
      GameMateCodeJob.perform_now(order.id)
    end
    assert_nil GameLead.find_by(email: "invitee@example.com").referrer_rewarded_at
  end

  test "a second qualifying order from the same address does not pay again" do
    referred_lead
    first = Order.create!(order_attrs(email: "invitee@example.com", subtotal: 100))
    Stripe::Coupon.stubs(:retrieve).returns(stub(id: "afida-stack-ref"))
    Stripe::PromotionCode.stubs(:create).returns(stub(code: "MATEC4NHW6"))
    GameMateCodeJob.perform_now(first.id)

    second = Order.create!(order_attrs(email: "invitee@example.com", subtotal: 150))
    assert_no_enqueued_emails do
      GameMateCodeJob.perform_now(second.id)
    end
  end

  test "does nothing when the referrer left no email" do
    referred_lead(referrer_email: nil)
    order = Order.create!(order_attrs(email: "invitee@example.com", subtotal: 100))

    assert_no_enqueued_emails do
      GameMateCodeJob.perform_now(order.id)
    end
  end

  test "a later email on the referrer flushes a payout that was waiting" do
    host = referred_lead(referrer_email: nil)
    order = Order.create!(order_attrs(email: "invitee@example.com", subtotal: 100))
    GameMateCodeJob.perform_now(order.id)
    assert_nil GameLead.find_by(email: "invitee@example.com").referrer_rewarded_at

    Stripe::Coupon.stubs(:retrieve).returns(stub(id: "afida-stack-ref"))
    Stripe::PromotionCode.stubs(:create).returns(stub(code: "MATEC4NHW6"))
    host.update!(email: "roastery@example.com")

    assert_enqueued_email_with GameMailer, :mate_code, args: [ "roastery@example.com", "MATEC4NHW6" ] do
      host.deliver_pending_referral_rewards
      perform_enqueued_jobs only: GameMateCodeJob
    end
  end

  test "shrugs off a deleted order" do
    assert_nothing_raised do
      GameMateCodeJob.perform_now(-1)
    end
  end
end
