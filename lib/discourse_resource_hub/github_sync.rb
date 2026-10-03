# frozen_string_literal: true

module ::DiscourseResourceHub
  # Bridges the GitHub API and the local `Resource` records.
  #
  # Responsibilities:
  #   * build a Resource from a repository reference
  #   * refresh an existing repository-backed Resource
  #   * import release assets as downloadable resources
  class GithubSync
    RELEASE_ASSET_EXTENSIONS = %w[
      zip tar gz tgz 7z rar dmg exe apk ipa deb rpm jar war
    ].freeze

    # Creates a resource backed by a GitHub repository.
    #
    # Raises if the repository is already linked, rather than silently adopting
    # another member's resource (which would let a caller refresh or mutate
    # records they do not own).
    def self.import_repository(reference, user:)
      full_name = GithubClient.normalize_repo(reference)
      raise GithubClient::Error.new(I18n.t("resource_hub.errors.invalid_repo")) if full_name.blank?

      data = GithubClient.repository(full_name)
      canonical = data["full_name"] || full_name

      if Resource.exists?(repo_full_name: canonical)
        raise GithubClient::Error.new(I18n.t("resource_hub.errors.already_linked"))
      end

      resource = Resource.new(repo_full_name: canonical, user: user)
      resource.category = Category.find_by(slug: "plugins") || Category.default
      resource.title = data["name"].presence || canonical.split("/").last
      resource.description = data["description"]

      apply_repo_attributes(resource, data)
      resource.save!

      import_releases(resource) if SiteSetting.resource_hub_github_import_releases

      resource
    end

    # Refresh metadata for a resource that is already linked. Returns true when
    # the record was updated.
    def self.refresh(resource, import_releases: false)
      return false if resource.repo_full_name.blank?

      data = GithubClient.repository(resource.repo_full_name)
      apply_repo_attributes(resource, data)
      resource.save!

      self.import_releases(resource) if import_releases && SiteSetting.resource_hub_github_import_releases

      true
    end

    def self.import_releases(resource)
      return 0 if resource.repo_full_name.blank?

      max = SiteSetting.resource_hub_github_max_releases.to_i
      return 0 if max <= 0

      releases = GithubClient.releases(resource.repo_full_name, per_page: max)
      return 0 unless releases.is_a?(Array)

      serialized =
        releases.filter_map do |release|
          next if release["draft"]

          assets =
            Array(release["assets"]).map do |asset|
              {
                "name" => asset["name"],
                "size" => asset["size"],
                "download_count" => asset["download_count"],
                "content_type" => asset["content_type"],
                "browser_download_url" => asset["browser_download_url"],
              }
            end

          {
            "tag_name" => release["tag_name"],
            "name" => release["name"].presence || release["tag_name"],
            "html_url" => release["html_url"],
            "published_at" => release["published_at"],
            "prerelease" => release["prerelease"],
            "body" => release["body"].to_s.truncate(2_000),
            "assets" => assets,
          }
        end

      metadata = (resource.repo_metadata || {}).dup
      metadata["releases"] = serialized
      metadata["latest_release"] = serialized.first
      resource.update_column(:repo_metadata, metadata)

      serialized.size
    end

    # Build the metadata hash stored on the resource from a repo payload.
    def self.apply_repo_attributes(resource, data)
      resource.repo_full_name = data["full_name"] || resource.repo_full_name
      resource.repo_url = data["html_url"] || resource.repo_url
      resource.repo_description = data["description"]
      resource.repo_stars = data["stargazers_count"].to_i
      resource.repo_forks = data["forks_count"].to_i
      resource.repo_watchers = data["watchers_count"].to_i
      resource.repo_open_issues = data["open_issues_count"].to_i
      resource.repo_language = data["language"]
      resource.repo_license =
        if data["license"].is_a?(Hash)
          data.dig("license", "spdx_id")
        else
          data["license"]
        end

      resource.repo_pushed_at = safe_time(data["pushed_at"])
      resource.repo_synced_at = Time.zone.now
      resource.source_url ||= data["html_url"]

      all_topics = Array(data["topics"])
      tracked = SiteSetting.resource_hub_github_topics.to_s.split("|").map(&:strip).reject(&:blank?)
      selected = (all_topics & tracked).presence || all_topics
      resource.topics = selected.first(Resource::MAX_TOPICS)

      metadata = (resource.repo_metadata || {}).dup
      metadata["homepage"] = data["homepage"]
      metadata["default_branch"] = data["default_branch"]
      metadata["archived"] = data["archived"]
      metadata["created_at"] = data["created_at"]
      metadata["updated_at"] = data["updated_at"]
      metadata["owner"] = data.dig("owner", "login")
      metadata["owner_avatar"] = data.dig("owner", "avatar_url")
      resource.repo_metadata = metadata
    end

    def self.safe_time(value)
      return nil if value.blank?

      Time.zone.parse(value.to_s)
    rescue ArgumentError
      nil
    end

    def self.release_downloadable?(name)
      extension = File.extname(name.to_s).delete_prefix(".").downcase
      extension.present? && RELEASE_ASSET_EXTENSIONS.include?(extension)
    end
  end
end
