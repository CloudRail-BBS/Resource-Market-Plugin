# frozen_string_literal: true

module ::DiscourseResourceHub
  class CommentSerializer < ::ApplicationSerializer
    attributes :id, :raw, :cooked, :username, :user_id, :created_at, :can_delete

    def username
      object.user&.username
    end

    # `scope` is Discourse's Guardian, injected by
    # ApplicationController#serialize_data. Anonymous visitors are represented by
    # Guardian::AnonymousUser, which has no `id`, so ownership is checked
    # defensively rather than calling Guardian#is_my_own?.
    def can_delete
      guardian = scope
      return false if guardian.blank?
      return true if guardian.is_staff?

      user = guardian.user
      return false unless user.respond_to?(:id) && user.id.present?

      object.user_id == user.id
    end
  end
end
