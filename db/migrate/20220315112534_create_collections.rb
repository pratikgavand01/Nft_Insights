class CreateCollections < ActiveRecord::Migration[7.0]
  def change
    create_table :collections do |t|
      t.string :slug
      t.string :name
      t.string :description
      t.string :url
      t.jsonb :stats
      t.jsonb :details

      t.timestamps
    end
    add_index :collections, :id, unique: true
    add_index :collections, :slug, unique: true
  end
end
