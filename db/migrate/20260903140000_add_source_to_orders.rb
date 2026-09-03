class AddSourceToOrders < ActiveRecord::Migration[8.1]
  def change
    # Where the order was placed: "web" for afida.com checkout, "agent" for a
    # purchase completed by an AI agent through Stripe Agentic Commerce.
    # Explicit rather than inferred from missing cart metadata, so reporting
    # and the reorder-schedule code can exclude agent orders deliberately.
    add_column :orders, :source, :string, null: false, default: "web"
    add_index :orders, :source
    # The agent that placed the order, from payment_intent.agent_details when
    # Stripe exposes it (private preview); nil until then.
    add_column :orders, :agent_name, :string
  end
end
