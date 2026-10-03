# frozen_string_literal: true

module ::Jobs
  module DiscourseResourceHub
    # Periodically refreshes every linked GitHub repository so stars, issues
    # and releases stay current without user interaction.
    class SyncGithubRepos < ::Jobs::Scheduled
      every 1.hour

      def execute(args)
        return unless SiteSetting.resource_hub_enabled
        return unless SiteSetting.resource_hub_github_enabled

        hours = SiteSetting.resource_hub_github_sync_hours.to_i
        return if hours <= 0

        # Cheap throttle: only do real work once per configured interval.
        next_run_key = "#{DiscourseResourceHub::PLUGIN_NAME}:next_github_sync"
        due_at = Discourse.cache.read(next_run_key)
        if due_at.present? && Time.zone.now < due_at
          return
        end

        Discourse.cache.write(next_run_key, hours.hours.from_now, expires_in: hours.hours + 1.hour)

        limit = args[:limit].to_i
        limit = 25 if limit <= 0

        synced = 0
        DiscourseResourceHub::Resource.repositories.approved.limit(limit).each do |resource|
          begin
            DiscourseResourceHub::GithubSync.refresh(resource, import_releases: true)
            synced += 1
          rescue DiscourseResourceHub::GithubClient::Error => e
            Rails.logger.warn(
              "[resource-hub] scheduled sync failed for #{resource.repo_full_name}: #{e.message}",
            )
          end

          sleep(0.5) if SiteSetting.resource_hub_github_token.blank?
        end

        Rails.logger.info("[resource-hub] scheduled GitHub sync finished, #{synced} repositories updated")
      end

      def self.schedule_next_run!
        Discourse.cache.delete("#{DiscourseResourceHub::PLUGIN_NAME}:next_github_sync")
      end
    end
  end
end
