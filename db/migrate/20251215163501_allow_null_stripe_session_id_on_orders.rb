class AllowNullStripeSessionIdOnOrders < ActiveRecord::Migration[8.1]
  def change
    # Allow stripe_session_id to be null for renewal orders which use stripe_invoice_id instead
    change_column_null :orders, :stripe_session_id, true
  end
end
