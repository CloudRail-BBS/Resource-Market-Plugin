# frozen_string_literal: true

# Seeds the default categories so the hub is usable immediately after install.
#
# Discourse runs exclusively on PostgreSQL, so `ON CONFLICT DO NOTHING` keeps
# this idempotent if the migration is re-run.
class SeedResourceHubCategories < ActiveRecord::Migration[7.0]
  # `name` 是界面上显示的名称，使用中文。
  #
  # `slug` 保持英文且不要改动：它既是 URL 标识，也是 `ON CONFLICT (slug)` 的
  # 依据。改掉 slug 会在已安装的站点上插入一批重复分类而不是改名。
  CATEGORIES = [
    { name: "插件", slug: "plugins", color: "E45735", icon: "plug", position: 0 },
    { name: "主题", slug: "themes", color: "25AAE2", icon: "palette", position: 1 },
    { name: "工具", slug: "tools", color: "0E76FD", icon: "wrench", position: 2 },
    { name: "文档与教程", slug: "docs", color: "9EB83B", icon: "book", position: 3 },
    { name: "数据集", slug: "datasets", color: "8C6DE4", icon: "database", position: 4 },
    { name: "其他", slug: "other", color: "919191", icon: "box", position: 5 },
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
