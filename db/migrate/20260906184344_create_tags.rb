# ported from community_bookshelf db/migrate (create_tags)
class CreateTags < ActiveRecord::Migration[8.1]
  def change
    create_table :tags do |t|
      t.string :name, null: false
      t.string :category, null: false, default: "genre"

      t.timestamps
    end
    add_index :tags, :name, unique: true
    add_index :tags, :category
  end
end
