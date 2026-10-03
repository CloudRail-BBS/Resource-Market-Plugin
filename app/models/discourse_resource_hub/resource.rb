# frozen_string_literal: true

module ::DiscourseResourceHub
  class Resource < ActiveRecord::Base
    self.table_name = "resource_hub_resources"

    STATUS_PENDING = 0
    STATUS_APPROVED = 1
    STATUS_REJECTED = 2

    STATUSES = {
      pending: STATUS_PENDING,
      approved: STATUS_APPROVED,
      rejected: STATUS_REJECTED,
    }.freeze

    MAX_TITLE_LENGTH = 200
    MAX_DESCRIPTION_LENGTH = 5_000
    MAX_TOPICS = 8

    belongs_to :user
    belongs_to :category, class_name: "DiscourseResourceHub::Category", foreign_key: :category_id, optional: true
    belongs_to :upload, optional: true
    has_many :comments, class_name: "DiscourseResourceHub::Comment", foreign_key: :resource_id, dependent: :destroy

    scope :approved, -> { where(status: STATUS_APPROVED) }
    scope :pending, -> { where(status: STATUS_PENDING) }
    scope :files, -> { where.not(upload_id: nil) }
    scope :repositories, -> { where.not(repo_full_name: nil) }
    scope :recent, -> { order(created_at: :desc) }
    scope :popular, -> { order(download_count: :desc, created_at: :desc) }

    before_validation :ensure_slug, on: :create
    before_validation :normalize_topics

    validates :title, presence: true, length: { maximum: MAX_TITLE_LENGTH }
    validates :description, length: { maximum: MAX_DESCRIPTION_LENGTH }, allow_blank: true
    validates :slug, presence: true, uniqueness: true
    validates :repo_full_name, uniqueness: true, allow_blank: true
    validate :repo_full_name_format

    def approved?
      status == STATUS_APPROVED
    end

    def pending?
      status == STATUS_PENDING
    end

    def repository?
      repo_full_name.present?
    end

    def file?
      upload_id.present?
    end

    # Human readable file size, derived from the associated upload.
    def file_size
      upload&.filesize
    end

    def extension
      return nil if upload.blank?

      File.extname(upload.original_filename.to_s).delete_prefix(".")
    end

    # The URL a visitor should hit to obtain the artifact. Uploads are served
    # through the download endpoint so we can count them; repositories without
    # a local asset link straight out to GitHub.
    def download_path
      return repo_url if external?

      "/resource-hub/resources/#{id}/download"
    end

    def external?
      repository? && upload_id.blank?
    end

    private

    def ensure_slug
      return if slug.present? || title.blank?

      base = title.parameterize.presence || "resource"
      candidate = base
      counter = 1

      while self.class.where(slug: candidate).exists?
        counter += 1
        candidate = "#{base}-#{counter}"
      end

      self.slug = candidate
    end

    def normalize_topics
      self.topics =
        Array(topics)
          .map { |topic| topic.to_s.strip.downcase }
          .reject(&:blank?)
          .uniq
          .first(MAX_TOPICS)
    end

    def repo_full_name_format
      return if repo_full_name.blank?
      return if repo_full_name.match?(%r{\A[\w.-]+/[\w.-]+\z})

      errors.add(:repo_full_name, "must look like owner/repo")
    end
  end
end
