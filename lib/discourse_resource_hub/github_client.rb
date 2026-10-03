# frozen_string_literal: true

require "net/http"
require "json"
require "uri"
require "cgi"
require "digest"

module ::DiscourseResourceHub
  # Thin wrapper around the public GitHub REST API (v2022-11-28).
  #
  # Every network call funnels through `get`, which centralises authentication,
  # error handling and rate limit reporting. Responses are memoised in-process
  # for a short window so that rendering a page with many repositories does not
  # burn through the anonymous rate limit.
  class GithubClient
    API_BASE = "https://api.github.com"
    ACCEPT = "application/vnd.github+json"
    API_VERSION = "2022-11-28"
    OPEN_TIMEOUT = 5
    READ_TIMEOUT = 12
    MEMO_TTL = 10.minutes

    class Error < StandardError
      attr_reader :status

      def initialize(message, status: nil)
        super(message)
        @status = status
      end

      def rate_limited?
        status == 403 || status == 429
      end

      def not_found?
        status == 404
      end
    end

    class << self
      def enabled?
        SiteSetting.resource_hub_github_enabled
      end

      # Parse and validate a user supplied repository reference.
      #
      # Accepts "owner/repo", a full GitHub URL, or a URL with a trailing
      # ".git" / "/tree/main" suffix and returns "owner/repo" or nil.
      def normalize_repo(reference)
        return nil if reference.blank?

        value = reference.to_s.strip

        if value.start_with?("http://", "https://")
          uri = begin
            URI.parse(value)
          rescue URI::InvalidURIError
            return nil
          end
          return nil unless uri.host&.match?(%r{\A(www\.)?github\.com\z}i)

          value = uri.path
        end

        value = value.delete_prefix("/").delete_suffix(".git")
        segments = value.split("/").reject(&:blank?)
        return nil if segments.size < 2

        owner, repo = segments[0], segments[1]
        return nil unless owner.match?(%r{\A[\w.-]+\z}) && repo.match?(%r{\A[\w.-]+\z})

        "#{owner}/#{repo}"
      end

      def repository(full_name)
        get("/repos/#{full_name}")
      end

      def releases(full_name, per_page: 10)
        get("/repos/#{full_name}/releases?per_page=#{per_page.to_i.clamp(1, 30)}")
      end

      # Search repositories. `sort` maps onto the GitHub search API.
      def search(query, sort: "stars", per_page: 20)
        allowed = %w[stars forks help-wanted-issues updated]
        sort = "stars" unless allowed.include?(sort)
        encoded = CGI.escape(query.to_s)
        get("/search/repositories?q=#{encoded}&sort=#{sort}&per_page=#{per_page.to_i.clamp(1, 50)}")
      end

      # Drops every memoised GitHub response. Used by the admin sync action so a
      # manual "Sync now" always observes fresh upstream data.
      def clear_cache!
        return unless Discourse.cache.respond_to?(:delete_matched)

        Discourse.cache.delete_matched("#{cache_prefix}*")
      end

      private

      def cache_prefix
        "#{DiscourseResourceHub::PLUGIN_NAME}:gh:"
      end

      def token
        SiteSetting.resource_hub_github_token.presence
      end

      # GET a GitHub API path, returning parsed JSON (Hash/Array).
      #
      # Results are memoised per path so a page rendering many repositories does
      # not exhaust the anonymous rate limit, and so concurrent requests never
      # read-modify-write a shared cache entry.
      def get(path, retries: 1)
        key = "#{cache_prefix}#{Digest::SHA1.hexdigest(path)}"
        cached = Discourse.cache.read(key)

        if cached.present?
          raise Error.new(cached[:error], status: cached[:status]) if cached[:error].present?

          return cached[:body]
        end

        body = perform_request(path)
        Discourse.cache.write(key, { body: body }, expires_in: MEMO_TTL)
        body
      rescue Error => e
        # Remember failures briefly (404s, rate limits) so we do not hammer the API.
        Discourse.cache.write(key, { error: e.message, status: e.status }, expires_in: 1.minute)
        raise e
      rescue Net::OpenTimeout, Net::ReadTimeout, Errno::ECONNRESET, SocketError
        return get(path, retries: retries - 1) if retries.positive?

        raise Error.new("network error")
      end

      def perform_request(path)
        uri = URI.parse("#{API_BASE}#{path}")
        request = Net::HTTP::Get.new(uri)
        request["Accept"] = ACCEPT
        request["X-GitHub-Api-Version"] = API_VERSION
        request["User-Agent"] = "#{DiscourseResourceHub::PLUGIN_NAME} (#{Discourse.base_url})"
        request["Authorization"] = "Bearer #{token}" if token.present?

        response =
          Net::HTTP.start(
            uri.host,
            uri.port,
            use_ssl: true,
            open_timeout: OPEN_TIMEOUT,
            read_timeout: READ_TIMEOUT,
          ) { |http| http.request(request) }

        code = response.code.to_i
        payload = parse_body(response.body)

        case code
        when 200, 201
          payload
        when 403, 429
          remaining = response["x-ratelimit-remaining"]
          message =
            if remaining == "0"
              I18n.t("resource_hub.errors.rate_limited")
            else
              payload.is_a?(Hash) ? payload["message"].to_s : "forbidden"
            end
          raise Error.new(message, status: code)
        when 404
          raise Error.new(I18n.t("resource_hub.errors.repo_not_found"), status: 404)
        else
          message = payload.is_a?(Hash) ? payload["message"].to_s : response.body.to_s
          raise Error.new(I18n.t("resource_hub.errors.github_error", message: message), status: code)
        end
      end

      def parse_body(raw)
        return nil if raw.blank?

        JSON.parse(raw)
      rescue JSON::ParserError
        nil
      end
    end
  end
end
