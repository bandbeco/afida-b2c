class SecureGameRewards < ActiveRecord::Migration[8.1]
  def up
    create_table :game_participants do |t|
      t.string :ref_code, null: false
      t.string :email
      t.string :experiment, null: false, default: "voucher_30_days"
      t.timestamps
    end
    add_index :game_participants, :ref_code, unique: true
    add_reference :leaderboard_entries, :game_participant, foreign_key: true
    add_reference :leaderboard_entries, :inviter, foreign_key: { to_table: :game_participants }
    add_reference :game_leads, :inviter, foreign_key: { to_table: :game_participants }
    add_reference :game_leads, :qualifying_order, foreign_key: { to_table: :orders }

    # Preserve every published gift URL. Old IP-based ownership is deliberately
    # not imported into browser sessions; a public link never grants ownership.
    execute <<~SQL
      INSERT INTO game_participants (ref_code, email, created_at, updated_at)
      SELECT ref_code, email, created_at, updated_at FROM leaderboard_entries WHERE ref_code IS NOT NULL;
      UPDATE leaderboard_entries e SET game_participant_id = p.id
      FROM game_participants p WHERE p.ref_code = e.ref_code;
      UPDATE leaderboard_entries e SET inviter_id = host.game_participant_id
      FROM leaderboard_entries host WHERE host.id = e.referrer_id;
      UPDATE game_leads l SET inviter_id = host.game_participant_id
      FROM leaderboard_entries host WHERE host.id = l.referrer_id;
    SQL

    create_table :game_prize_budgets do |t|
      t.string :kind, null: false
      t.date :month, null: false
      t.integer :reserved, null: false, default: 0
      t.timestamps
    end
    add_index :game_prize_budgets, [ :kind, :month ], unique: true

    create_table :game_awards do |t|
      t.string :grant_key, null: false
      t.string :email, null: false
      t.string :kind, null: false
      t.date :month, null: false
      t.datetime :expires_at, null: false
      t.string :code
      t.references :game_participant, foreign_key: true
      t.references :qualifying_order, foreign_key: { to_table: :orders }
      t.references :redeemed_order, foreign_key: { to_table: :orders }
      t.timestamps
    end
    add_index :game_awards, :grant_key, unique: true
    add_index :game_awards, :code, unique: true
    add_index :game_awards, [ :kind, :month ]

    # Existing awards count against the launch month's reservation budget.
    # Their Stripe codes keep their ORIGINAL expiry and cannot be extended by DB.
    execute <<~SQL
      INSERT INTO game_awards (grant_key, email, kind, month, expires_at, code, created_at, updated_at)
      SELECT 'win:' || id || ':' || to_char(win_promo_month, 'YYYY-MM-DD'), email, 'win', win_promo_month,
        (win_promo_month + interval '1 month')::timestamp AT TIME ZONE 'Europe/London', win_promo_code, created_at, updated_at
      FROM game_leads WHERE win_promo_code IS NOT NULL AND win_promo_month IS NOT NULL;
      INSERT INTO game_prize_budgets (kind, month, reserved, created_at, updated_at)
      SELECT kind, month, count(*), CURRENT_TIMESTAMP, CURRENT_TIMESTAMP FROM game_awards GROUP BY kind, month;
    SQL

    create_table :game_events do |t|
      t.references :game_participant, foreign_key: true
      t.references :order, foreign_key: true
      t.string :name, null: false
      t.string :event_key, null: false
      t.jsonb :properties, null: false, default: {}
      t.timestamps
    end
    add_index :game_events, :event_key, unique: true
    add_index :game_events, [ :name, :created_at ]

    create_table :game_crowns do |t|
      t.date :month, null: false
      t.references :leaderboard_entry, foreign_key: true
      t.string :publication_url
      t.datetime :published_at
      t.timestamps
    end
    add_index :game_crowns, :month, unique: true
  end

  def down
    drop_table :game_crowns
    drop_table :game_events
    drop_table :game_awards
    drop_table :game_prize_budgets
    remove_reference :game_leads, :qualifying_order, foreign_key: { to_table: :orders }
    remove_reference :game_leads, :inviter, foreign_key: { to_table: :game_participants }
    remove_reference :leaderboard_entries, :inviter, foreign_key: { to_table: :game_participants }
    remove_reference :leaderboard_entries, :game_participant, foreign_key: true
    drop_table :game_participants
  end
end
