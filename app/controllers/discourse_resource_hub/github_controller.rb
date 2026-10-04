# frozen_string_literal: true

module ::DiscourseResourceHub
  class GithubController < ::ApplicationController
    requires_plugin PLUGIN_NAME
    include DiscourseResourceHub::SerializationHelpers

    # Every GitHub endpoint requires a session. The search endpoint proxies the
    # shared GitHub API quota (60 req/h anonymous, 5000 with a token), so leaving
    # it open to anonymous visitors would let anyone exhaust the site's budget.
    before_action :ensure_enabled
    before_action :ensure_github_enabled
    before_action :ensure_logged_in

    # GET /resource-hub/github/search.json?q=...
    def search
      query = params[:q].to_s.strip.first(100)
      return render json: { repositories: [], total: 0 } if query.blank?

      RateLimiter.new(current_user, "resource-hub-github-search", 15, 1.minute).performed!

      results = GithubClient.search(query, sort: params[:sort], per_page: params[:per_page] || 20)
      items = Array(results["items"])
      render json: { repositories: items.map { |item| preview(item) }, total: results["total_count"].to_i }
    rescue GithubClient::Error => e
      render_json_error(e.message, status: e.rate_limited? ? 429 : 422)
    end

    # GET /resource-hub/github/repo.json?repo=owner/name
    def show
      full_name = normalize_or_raise(params[:repo])
      data = GithubClient.repository(full_name)

      render json: {
               repository: preview(data),
               releases: safe_releases(full_name),
               already_linked: Resource.exists?(repo_full_name: data["full_name"]),
             }
    rescue GithubClient::Error => e
      render_json_error(e.message, status: e.not_found? ? 404 : 422)
    end

    # POST /resource-hub/github/repo.json
    #
    # Creates a resource backed by a GitHub repository. Linking is a publish
    # action, so it is gated on the same permission as uploading a file.
    def link
      raise Discourse::InvalidAccess unless DiscourseResourceHub::Guardian.new(current_user).can_upload?

      resource = GithubSync.import_repository(params[:repo], user: current_user)
      render json: { resource: serialize_one(resource, ResourceSerializer) }, status: :created
    rescue GithubClient::Error => e
      render_json_error(e.message, status: e.not_found? ? 404 : 422)
    rescue ActiveRecord::RecordInvalid => e
      render_json_error(e.record.errors.full_messages.join(", "), status: 422)
    end

    # POST /resource-hub/github/repo/sync.json
    def sync
      raise Discourse::InvalidAccess unless current_user.staff?

      # Drop memoised responses so a manual sync always reads fresh upstream data.
      GithubClient.clear_cache!

      records =
        if params[:resource_id].present?
          record = Resource.find_by(id: params[:resource_id])
          raise Discourse::NotFound if record.blank?

          [record]
        else
          Resource.repositories.limit(params[:limit].present? ? params[:limit].to_i.clamp(1, 100) : 25)
        end

      synced = 0
      errors = []

      records.each do |record|
        GithubSync.refresh(record, import_releases: true)
        synced += 1
      rescue GithubClient::Error => e
        errors << { repo: record.repo_full_name, message: e.message }
        Rails.logger.warn("[resource-hub] github sync failed for #{record.repo_full_name}: #{e.message}")
      end

      render json: { synced: synced, errors: errors }
    end

    # DELETE /resource-hub/github/repo.json
    #
    # Detaches the repository. A resource with no repository *and* no upload
    # would have nothing to deliver, so that case is rejected instead of being
    # silently left in a broken state.
    def unlink
      resource = Resource.find_by(id: params[:resource_id])
      raise Discourse::NotFound if resource.blank?
      raise Discourse::InvalidAccess unless current_user.staff? || resource.user_id == current_user.id
      raise Discourse::InvalidParameters.new(:resource_id) if resource.upload_id.blank?

      resource.update!(repo_full_name: nil, repo_url: nil, repo_metadata: {})
      render json: { success: true }
    end

    private

    def ensure_enabled
      raise Discourse::NotFound unless SiteSetting.resource_hub_enabled
    end

    def ensure_github_enabled
      raise Discourse::NotFound unless SiteSetting.resource_hub_github_enabled
    end

    def normalize_or_raise(reference)
      full_name = GithubClient.normalize_repo(reference)
      raise GithubClient::Error.new(I18n.t("resource_hub.errors.invalid_repo")) if full_name.blank?

      full_name
    end

    # Projects a GitHub payload (repository or search result) onto the fields the
    # client needs, so raw upstream JSON is never forwarded verbatim.
    def preview(item)
      {
        full_name: item["full_name"],
        html_url: item["html_url"],
        description: item["description"],
        stars: item["stargazers_count"].to_i,
        forks: item["forks_count"].to_i,
        language: item["language"],
        topics: Array(item["topics"]),
        owner_avatar: item.dig("owner", "avatar_url"),
        license: item["license"].is_a?(Hash) ? item.dig("license", "spdx_id") : item["license"],
        updated_at: item["updated_at"],
      }
    end

    def safe_releases(full_name)
      GithubClient.releases(full_name, per_page: 10)
    rescue GithubClient::Error => e
      Rails.logger.debug("[resource-hub] could not load releases for #{full_name}: #{e.message}")
      []
    end
  end
end
