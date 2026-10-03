# frozen_string_literal: true

module ::DiscourseResourceHub
  class Comment < ActiveRecord::Base
    self.table_name = "resource_hub_comments"

    MAX_RAW_LENGTH = 2_000

    belongs_to :resource, class_name: "DiscourseResourceHub::Resource", foreign_key: :resource_id
    belongs_to :user

    validates :raw, presence: true, length: { maximum: MAX_RAW_LENGTH }

    scope :chronological, -> { order(created_at: :asc) }

    # Comments are immutable once posted, so cooking only needs to happen on
    # create. PrettyText sanitises the output, so storing `cooked` is safe to
    # render with htmlSafe on the client.
    before_create :cook_raw

    private

    def cook_raw
      return if raw.blank?

      self.cooked = PrettyText.cook(raw, features: { onebox: false })
    end
  end
end
