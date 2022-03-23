class CreateAssets < ActiveRecord::Migration[7.0]
  def change
    create_table :assets do |t|
      t.string :token_id
      t.string :name
      t.string :description
      t.datetime :contract_date
      t.text :url
      t.text :img_url
      t.string :current_price
      t.datetime :price_updated_timestamp
      t.references :collection, null: false, foreign_key: true
      t.jsonb :details

      t.timestamps
    end
    add_index :assets, :url, unique: true
    add_index :assets, :token_id, unique: true
  end
end
