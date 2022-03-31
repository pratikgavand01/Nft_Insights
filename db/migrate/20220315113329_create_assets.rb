class CreateAssets < ActiveRecord::Migration[7.0]
  def change
    create_table :assets do |t|
      t.string :token_id
      t.string :name
      t.string :description
      t.datetime :asset_contract_date
      t.string :asset_contract_address
      t.text :url
      t.text :img_url
      t.string :current_price
      t.string :last_event_type
      t.string :duration
      t.datetime :price_updated_timestamp
      t.references :collection, null: false, foreign_key: true
      t.jsonb :details

      t.timestamps
    end
    add_index :assets, :url, unique: true
  end
end
