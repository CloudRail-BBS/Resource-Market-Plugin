# frozen_string_literal: true

class CreateResourceHubCategories < ActiveRecord::Migration[7.0]
  def change
    create_table :resource_hub_categories do |t|
      t.string :name, null: false
      t.string :slug, null: false
      t.string :color, null: false, default: "5865F2"
      t.string :icon, null: false, default: "folder"
      t.text :description
      t.integer :position, null: false, default: 0
      t.integer :resource_count, null: false, default: 0

      t.timestamps
    end

    add_index :resource_hub_categories, :slug, unique: true
    add_index :resource_hub_categories, :position
  end
end
