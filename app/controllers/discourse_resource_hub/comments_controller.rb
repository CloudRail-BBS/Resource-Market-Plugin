# frozen_string_literal: true

module ::DiscourseResourceHub
  class CommentsController < ::ApplicationController
    requires_plugin PLUGIN_NAME

    before_action :ensure_enabled
    before_action :fetch_resource
    before_action :ensure_logged_in, except: :index

    # GET /resource-hub/resources/:id/comments.json
    def index
      comments = @resource.comments.includes(:user).chronological
      render json: { comments: serialize_data(comments, CommentSerializer) }
    end

    # POST /resource-hub/resources/:id/comments.json
    def create
      comment = Comment.new(resource_id: @resource.id, user_id: current_user.id, raw: params[:raw].to_s.strip)

      if comment.raw.blank?
        return render_json_error(I18n.t("resource_hub.errors.comment_required"), status: 422)
      end

      RateLimiter.new(current_user, "resource-hub-comments", 20, 1.minute).performed!
      comment.save!
      render json: { comment: serialize_data(comment, CommentSerializer) }, status: :created
    rescue ActiveRecord::RecordInvalid => e
      render_json_error(e.record.errors.full_messages.join(", "), status: 422)
    end

    # DELETE /resource-hub/resources/:id/comments/:comment_id.json
    def destroy
      comment = @resource.comments.find_by(id: params[:comment_id])
      raise Discourse::NotFound if comment.blank?
      raise Discourse::InvalidAccess unless current_user.staff? || comment.user_id == current_user.id

      comment.destroy!
      render json: { success: true }
    end

    private

    def ensure_enabled
      raise Discourse::NotFound unless SiteSetting.resource_hub_enabled
    end

    def fetch_resource
      value = params[:id].to_s
      @resource =
        Resource.find_by(slug: value) ||
          (Resource.find_by(id: value.to_i) if value.match?(/\A\d+\z/))
      raise Discourse::NotFound if @resource.blank?

      return if @resource.approved?

      # Pending and rejected resources are only visible to their author and staff.
      unless current_user.present? && (current_user.staff? || @resource.user_id == current_user.id)
        raise Discourse::InvalidAccess
      end
    end
  end
end
