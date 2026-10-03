# frozen_string_literal: true

module ::DiscourseResourceHub
  class Engine < ::Rails::Engine
    engine_name PLUGIN_NAME
    isolate_namespace DiscourseResourceHub

    # NOTE: `lib/` is deliberately NOT added to `config.autoload_paths`.
    #
    # Discourse plugins have two loaders and mixing them breaks boot: `app/` is
    # owned by Zeitwerk, while `lib/` is plain Ruby that `plugin.rb` requires
    # explicitly with `require_relative`. Registering `lib/` as an autoload path
    # while also requiring those same files makes Zeitwerk and the explicit
    # require fight over the same constants.
    #
    # The consequence is that changes under `lib/` need a server restart rather
    # than hot reloading, which is the accepted trade-off for this plugin.

    # Scheduled jobs must be eager-loaded so that `Jobs::Scheduled.descendants`
    # includes them and the scheduler can find them.
    scheduled_job_dir = "#{config.root}/app/jobs/scheduled"
    config.to_prepare do
      Rails.autoloaders.main.eager_load_dir(scheduled_job_dir) if Dir.exist?(scheduled_job_dir)
    end
  end
end
