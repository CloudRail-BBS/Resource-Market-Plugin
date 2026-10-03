# frozen_string_literal: true

class CreateResourceHubResources < ActiveRecord::Migration[7.0]
  def change
    create_table :resource_hub_resources do |t|
      t.string :title, null: false
      t.text :description
      t.string :slug, null: false
      t.integer :user_id, null: false
      t.integer :category_id
      t.integer :upload_id
      t.integer :download_count, null: false, default: 0
      t.integer :status, null: false, default: 1
      t.string :version
      t.string :source_url
      t.string :topics, array: true, null: false, default: []

      # GitHub repository integration fields
      t.string :repo_full_name
      t.string :repo_url
      t.integer :repo_stars, null: false, default: 0
      t.integer :repo_forks, null: false, default: 0
      t.integer :repo_watchers, null: false, default: 0
      t.integer :repo_open_issues, null: false, default: 0
      t.string :repo_language
      t.string :repo_license
      t.text :repo_description
      t.datetime :repo_pushed_at
      t.datetime :repo_synced_at
      t.jsonb :repo_metadata, null: false, default: {}

      t.timestamps
    end

    add_index :resource_hub_resources, :slug, unique: true
    add_index :resource_hub_resources, :user_id
    add_index :resource_hub_resources, :category_id
    add_index :resource_hub_resources, :status
    add_index :resource_hub_resources, :download_count
    add_index :resource_hub_resources, :repo_full_name, unique: true
  end
end
