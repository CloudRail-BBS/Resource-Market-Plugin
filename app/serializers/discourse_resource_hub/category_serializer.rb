# frozen_string_literal: true

module ::DiscourseResourceHub
  class CategorySerializer < ::ApplicationSerializer
    attributes :id, :name, :slug, :color, :icon, :description, :position, :resource_count
  end
end
