# frozen_string_literal: true

module ::DiscourseResourceHub
  class ResourcesController < ::ApplicationController
    requires_plugin PLUGIN_NAME

    before_action :ensure_enabled
    before_action :ensure_logged_in, only: %i[create update destroy review]
    before_action :fetch_resource, only: %i[show update destroy review download]
    before_action :ensure_can_manage, only: %i[update destroy]

    DEFAULT_PER_PAGE = 24
    MAX_PER_PAGE = 60

    def index
      page = params[:page].to_i.clamp(1, 10_000)
      per_page = (params[:per_page].presence || DEFAULT_PER_PAGE).to_i.clamp(1, MAX_PER_PAGE)
      resources = Resource.includes(:user, :category, :upload)

      mine = params[:mine] == "true" || params[:type] == "mine"
      resources =
        if mine && current_user.present?
          resources.where(user_id: current_user.id)
        else
          resources.approved
        end

      if params[:category_id].present?
        resources = resources.where(category_id: params[:category_id].to_i)
      end

      case params[:type]
      when "files"
        resources = resources.files
      when "repositories"
        resources = resources.repositories
      end

      if params[:q].present?
        term = "%#{ActiveRecord::Base.sanitize_sql_like(params[:q].to_s.strip.first(100))}%"
        resources =
          resources.where(
            "title ILIKE :term OR description ILIKE :term OR repo_full_name ILIKE :term",
            term: term,
          )
      end

      if params[:topic].present?
        resources = resources.where("? = ANY(topics)", params[:topic].to_s.downcase.first(100))
      end

      resources =
        case params[:sort]
        when "popular"
          resources.popular
        when "name"
          resources.order(Arel.sql("LOWER(title) ASC"))
        else
          resources.recent
        end

      total = resources.count
      records = resources.offset((page - 1) * per_page).limit(per_page)

      render json: {
               resources: serialize_data(records, ResourceSerializer),
               categories: serialize_data(Category.ordered, CategorySerializer),
               meta: {
                 total: total,
                 page: page,
                 per_page: per_page,
                 has_more: page * per_page < total,
               },
               can_upload: resource_guardian.can_upload?,
               can_review: current_user&.staff? || false,
               title: SiteSetting.resource_hub_title,
               description: SiteSetting.resource_hub_description,
             }
    end

    def show
      render json: {
               resource: serialize_data(@resource, ResourceSerializer),
               comments: serialize_data(@resource.comments.includes(:user).chronological, CommentSerializer),
               can_manage: resource_guardian.can_manage?(@resource),
             }
    end

    def create
      raise Discourse::InvalidAccess unless resource_guardian.can_upload?

      resource =
        Resource.new(
          title: params[:title].to_s.strip,
          description: params[:description].to_s.strip,
          version: params[:version].presence,
          category_id: resolved_category_id,
          topics: parse_topics(params[:tags]),
          user_id: current_user.id,
          status: resource_guardian.can_auto_approve? ? Resource::STATUS_APPROVED : Resource::STATUS_PENDING,
        )

      if params[:upload_id].present?
        upload = Upload.find_by(id: params[:upload_id])
        raise Discourse::InvalidParameters.new(:upload_id) if upload.blank?
        raise Discourse::InvalidAccess unless upload.user_id == current_user.id || current_user.staff?

        validate_upload!(upload)
        resource.upload = upload
      elsif params[:repo_url].present?
        raise Discourse::InvalidAccess unless SiteSetting.resource_hub_github_enabled

        apply_repo!(resource)
      else
        return render_json_error(I18n.t("resource_hub.errors.invalid_upload"), status: 422)
      end

      resource.save!
      Category.find_by(id: resource.category_id)&.count_resources
      render json: { resource: serialize_data(resource, ResourceSerializer) }, status: :created
    rescue ActiveRecord::RecordInvalid => e
      render_json_error(e.record.errors.full_messages.join(", "), status: 422)
    rescue GithubClient::Error => e
      render_json_error(e.message, status: e.not_found? ? 404 : 422)
    end

    def update
      old_category_id = @resource.category_id
      @resource.title = params[:title].to_s.strip if params.key?(:title)
      @resource.description = params[:description].to_s.strip if params.key?(:description)
      @resource.version = params[:version].presence if params.key?(:version)
      @resource.topics = parse_topics(params[:tags]) if params.key?(:tags)
      @resource.category_id = resolved_category_id if params.key?(:category_id)
      @resource.save!

      Category.where(id: [old_category_id, @resource.category_id].compact.uniq).each(&:count_resources)
      render json: { resource: serialize_data(@resource, ResourceSerializer) }
    rescue ActiveRecord::RecordInvalid => e
      render_json_error(e.record.errors.full_messages.join(", "), status: 422)
    end

    # Only staff may approve or reject a submission. Authors may edit their own
    # metadata, but cannot transition their own review status.
    def review
      raise Discourse::InvalidAccess unless current_user.staff?

      status = Resource::STATUSES[params[:status].to_s.to_sym]
      unless [Resource::STATUS_APPROVED, Resource::STATUS_REJECTED].include?(status)
        return render_json_error("status must be approved or rejected", status: 422)
      end

      @resource.update!(status: status)
      @resource.category&.count_resources
      render json: { resource: serialize_data(@resource, ResourceSerializer) }
    end

    def destroy
      category = @resource.category
      @resource.destroy!
      category&.count_resources
      render json: { success: true }
    end

    # The download endpoint never accepts a caller-supplied URL. A repository
    # points at a canonical GitHub URL and a file uses Discourse's storage API
    # (which signs secure S3 URLs instead of exposing their raw object path).
    def download
      if @resource.external?
        url = @resource.repo_url
      elsif @resource.upload.present?
        if current_user.blank? && SiteSetting.prevent_anons_from_downloading_files
          raise Discourse::InvalidAccess
        end
        url = Discourse.store.url_for(@resource.upload, force_download: true)
      else
        return render_json_error(I18n.t("resource_hub.errors.resource_not_found"), status: 404)
      end

      if SiteSetting.resource_hub_count_downloads
        Resource.where(id: @resource.id).update_all("download_count = download_count + 1")
      end
      render json: { redirect_url: url, file_name: @resource.upload&.original_filename }
    end

    private

    def ensure_enabled
      raise Discourse::NotFound unless SiteSetting.resource_hub_enabled
    end

    def resource_guardian
      @resource_guardian ||= DiscourseResourceHub::Guardian.new(current_user)
    end

    def fetch_resource
      value = params[:id].to_s
      @resource =
        Resource.includes(:user, :category, :upload).find_by(slug: value) ||
          (Resource.includes(:user, :category, :upload).find_by(id: value.to_i) if value.match?(/\A\d+\z/))
      raise Discourse::NotFound if @resource.blank?
      raise Discourse::InvalidAccess if !@resource.approved? && !resource_guardian.can_manage?(@resource)
    end

    def ensure_can_manage
      raise Discourse::InvalidAccess unless resource_guardian.can_manage?(@resource)
    end

    def resolved_category_id
      return Category.default&.id if params[:category_id].blank?

      category = Category.find_by(id: params[:category_id].to_i)
      raise Discourse::InvalidParameters.new(:category_id) if category.blank?

      category.id
    end

    def parse_topics(value)
      raw = value.is_a?(Array) ? value : value.to_s.split(",")
      raw.map { |topic| topic.to_s.strip.downcase.first(80) }.reject(&:blank?).uniq.first(Resource::MAX_TOPICS)
    end

    def validate_upload!(upload)
      extension = File.extname(upload.original_filename.to_s).delete_prefix(".").downcase
      allowed = SiteSetting.resource_hub_authorized_extensions.to_s.split("|").map(&:strip)
      unless extension.present? && allowed.include?(extension)
        raise Discourse::InvalidParameters.new(:upload_id)
      end

      maximum = SiteSetting.resource_hub_max_file_size_kb.to_i.kilobytes
      if maximum <= 0 || upload.filesize.to_i > maximum
        raise Discourse::InvalidParameters.new(:upload_id)
      end
    end

    def apply_repo!(resource)
      full_name = GithubClient.normalize_repo(params[:repo_url])
      raise GithubClient::Error.new(I18n.t("resource_hub.errors.invalid_repo")) if full_name.blank?
      if Resource.exists?(repo_full_name: full_name)
        raise GithubClient::Error.new(I18n.t("resource_hub.errors.already_linked"))
      end

      data = GithubClient.repository(full_name)
      GithubSync.apply_repo_attributes(resource, data)
      resource.description = data["description"] if resource.description.blank?
      resource.source_url = resource.repo_url
    end
  end
end
