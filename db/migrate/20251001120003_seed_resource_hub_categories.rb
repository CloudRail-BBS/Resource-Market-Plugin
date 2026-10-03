# frozen_string_literal: true

# Seeds the default categories so the hub is usable immediately after install.
#
# Discourse runs exclusively on PostgreSQL, so `ON CONFLICT DO NOTHING` keeps
# this idempotent if the migration is re-run.
class SeedResourceHubCategories < ActiveRecord::Migration[7.0]
  CATEGORIES = [
    { name: "Plugins", slug: "plugins", color: "E45735", icon: "plug", position: 0 },
    { name: "Themes", slug: "themes", color: "25AAE2", icon: "palette", position: 1 },
    { name: "Tools", slug: "tools", color: "0E76FD", icon: "wrench", position: 2 },
    { name: "Docs & Guides", slug: "docs", color: "9EB83B", icon: "book", position: 3 },
    { name: "Datasets", slug: "datasets", color: "8C6DE4", icon: "database", position: 4 },
    { name: "Other", slug: "other", color: "919191", icon: "box", position: 5 },
  ].freeze

  def up
    return unless table_exists?(:resource_hub_categories)

    now = quote(Time.zone.now)

    CATEGORIES.each do |attrs|
      execute(<<~SQL)
        INSERT INTO resource_hub_categories
          (name, slug, color, icon, position, resource_count, created_at, updated_at)
        VALUES (
          #{quote(attrs[:name])},
          #{quote(attrs[:slug])},
          #{quote(attrs[:color])},
          #{quote(attrs[:icon])},
          #{attrs[:position]},
          0,
          #{now},
          #{now}
        )
        ON CONFLICT (slug) DO NOTHING
      SQL
    end
  end

  def down
    return unless table_exists?(:resource_hub_categories)

    execute(<<~SQL)
      DELETE FROM resource_hub_categories
      WHERE slug IN (#{CATEGORIES.map { |attrs| quote(attrs[:slug]) }.join(", ")})
    SQL
  end
end
