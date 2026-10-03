# frozen_string_literal: true

module ::DiscourseResourceHub
  class ResourceSerializer < ActiveModel::Serializer
    attributes :id,
               :title,
               :description,
               :slug,
               :version,
               :status,
               :download_count,
               :created_at,
               :updated_at,
               :source_url,
               :topics,
               :username,
               :category_id,
               :category_name,
               :category_slug,
               :category_color,
               :file_size,
               :file_name,
               :extension,
               :download_path,
               :external,
               :repository,
               :github

    def username
      object.user&.username
    end

    def category_name
      object.category&.name
    end

    def category_slug
      object.category&.slug
    end

    def category_color
      object.category&.color
    end

    def file_name
      object.upload&.original_filename
    end

    # ActiveModel::Serialization reads each declared attribute with `send(name)`
    # (activemodel/lib/active_model/serialization.rb: `send(key)`), and
    # ActiveRecord does not override that. So an attribute must resolve to a
    # column, a model method, or a reader defined here.
    #
    # The model exposes `external?`, not `external`. Without this reader the
    # `:external` attribute below raises
    #   NoMethodError: undefined method 'external' for an instance of
    #   DiscourseResourceHub::Resource
    # and EVERY hub endpoint 500s — index, show and create all serialise this
    # class — which presents as "the page loads but nothing works".
    def external
      object.external?
    end

    def repository
      object.repository?
    end

    # GitHub payload, only present for repository-backed resources.
    def github
      return nil unless object.repository?

      {
        full_name: object.repo_full_name,
        html_url: object.repo_url,
        description: object.repo_description,
        stars: object.repo_stars,
        forks: object.repo_forks,
        watchers: object.repo_watchers,
        open_issues: object.repo_open_issues,
        language: object.repo_language,
        license: object.repo_license,
        pushed_at: object.repo_pushed_at,
        synced_at: object.repo_synced_at,
        topics: object.topics,
        latest_release: object.repo_metadata&.dig("latest_release"),
        releases: object.repo_metadata&.dig("releases") || [],
      }
    end
  end
end
