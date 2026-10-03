# frozen_string_literal: true

module ::DiscourseResourceHub
  class CategorySerializer < ActiveModel::Serializer
    attributes :id, :name, :slug, :color, :icon, :description, :position, :resource_count
  end
end
