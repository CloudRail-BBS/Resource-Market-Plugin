# frozen_string_literal: true

module ::DiscourseResourceHub
  class Category < ActiveRecord::Base
    self.table_name = "resource_hub_categories"

    has_many :resources,
             class_name: "DiscourseResourceHub::Resource",
             foreign_key: :category_id,
             dependent: :nullify

    before_validation :ensure_slug

    validates :name, presence: true, length: { maximum: 60 }
    validates :slug, presence: true, uniqueness: true

    scope :ordered, -> { order(:position, :name) }

    def self.default
      ordered.first
    end

    def count_resources
      update_column(:resource_count, resources.approved.count)
    end

    private

    def ensure_slug
      return if slug.present? || name.blank?

      self.slug = name.parameterize
    end
  end
end
