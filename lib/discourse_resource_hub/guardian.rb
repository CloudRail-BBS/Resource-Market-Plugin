# frozen_string_literal: true

module ::DiscourseResourceHub
  # Policy object shared between controllers and serializers.
  class Guardian
    def initialize(user)
      @user = user
    end

    def user
      @user
    end

    def can_upload?
      return false if @user.blank?
      return true if staff?

      groups = SiteSetting.resource_hub_upload_allowed_groups_map
      return true if groups.blank?

      (user_group_ids & groups).present?
    end

    def can_auto_approve?
      return false if @user.blank?
      return true if staff?

      groups = SiteSetting.resource_hub_auto_approve_groups_map
      return false if groups.blank?

      (user_group_ids & groups).present?
    end

    def can_manage?(resource)
      return false if @user.blank?

      staff? || resource.user_id == @user.id
    end

    def can_delete?(comment)
      return false if @user.blank?

      staff? || comment.user_id == @user.id
    end

    def can_download?(resource)
      return false unless resource.approved?

      true
    end

    private

    def staff?
      @user.present? && @user.staff?
    end

    def user_group_ids
      @user_group_ids ||= @user.group_users.pluck(:group_id)
    end
  end
end
