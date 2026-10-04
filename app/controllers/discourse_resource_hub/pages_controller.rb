# frozen_string_literal: true

module ::DiscourseResourceHub
  # Serves the Discourse application shell for direct visits, refreshes, and
  # Discourse's own preload XHRs.
  #
  # Resource data always comes from the JSON API in ResourcesController; this
  # controller only renders the shell so the Ember app can boot on a cold URL.
  class PagesController < ::ApplicationController
    requires_plugin PLUGIN_NAME
    skip_before_action :check_xhr, only: :index

    def index
      raise Discourse::NotFound unless SiteSetting.resource_hub_enabled

      render :index
    end
  end
end
