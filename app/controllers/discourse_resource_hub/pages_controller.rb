# frozen_string_literal: true

module ::DiscourseResourceHub
  # Serves the Discourse application shell for direct visits and refreshes.
  # Resource data always comes from the JSON API in ResourcesController.
  class PagesController < ::ApplicationController
    requires_plugin PLUGIN_NAME
    skip_before_action :check_xhr, only: :index

    def index
      raise Discourse::NotFound unless SiteSetting.resource_hub_enabled
      raise Discourse::NotFound unless request.format.html?

      render :index
    end
  end
end
