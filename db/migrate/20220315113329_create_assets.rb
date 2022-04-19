class CreateAssets < ActiveRecord::Migration[7.0]
  TEXT_BYTES = 1_073_741_823

  def change
    create_table :assets do |t|
      t.string :token_id
      t.string :name
      t.string :description
      t.datetime :asset_contract_date
      t.string :asset_contract_address
      t.text :url, limit: TEXT_BYTES
      t.text :img_url, limit: TEXT_BYTES
      t.string :current_price
      t.string :last_event_type
      t.string :duration
      t.datetime :price_updated_timestamp
      t.references :collection, null: false, foreign_key: true
      t.jsonb :details

      t.timestamps
    end

    add_index :assets, :id, unique: true
    add_index :assets, :price_updated_timestamp
    add_index :assets, :url, unique: true
  end
end
