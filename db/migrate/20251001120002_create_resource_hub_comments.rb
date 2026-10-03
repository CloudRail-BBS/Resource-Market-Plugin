# frozen_string_literal: true

class CreateResourceHubComments < ActiveRecord::Migration[7.0]
  def change
    create_table :resource_hub_comments do |t|
      t.integer :resource_id, null: false
      t.integer :user_id, null: false
      t.text :raw, null: false
      t.text :cooked
      t.integer :reply_to_id

      t.timestamps
    end

    add_index :resource_hub_comments, :resource_id
    add_index :resource_hub_comments, :user_id
    add_index :resource_hub_comments, %i[resource_id created_at]
  end
end
