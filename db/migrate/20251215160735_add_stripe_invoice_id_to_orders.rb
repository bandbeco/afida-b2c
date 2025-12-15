class AddStripeInvoiceIdToOrders < ActiveRecord::Migration[8.1]
  def change
    add_column :orders, :stripe_invoice_id, :string
    # Partial unique index - allows multiple NULLs but enforces uniqueness for non-NULL values
    # Used for idempotency in webhook-created renewal orders
    add_index :orders, :stripe_invoice_id, unique: true, where: "stripe_invoice_id IS NOT NULL"
  end
end
