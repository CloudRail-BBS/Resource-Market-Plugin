# frozen_string_literal: true

# name: discourse-resource-hub
# about: A resource centre for Discourse: upload files, download community artefacts, and link GitHub repositories.
# meta_topic_id: 0
# version: 1.0.0
# authors: Resource Hub Contributors
# url: https://github.com/CloudRail-BBS/Resource-Market-Plugin
# required_version: 3.4.0
# license: MIT

enabled_site_setting :resource_hub_enabled

register_svg_icon "book-open"
register_svg_icon "file-arrow-down"
register_svg_icon "cloud-arrow-up"
register_svg_icon "code-branch"
register_svg_icon "star"
register_svg_icon "download"
register_svg_icon "tag"
register_svg_icon "paperclip"
register_svg_icon "rotate"
register_svg_icon "trash-can"
register_svg_icon "circle-info"
register_svg_icon "arrow-left"
register_svg_icon "xmark"
register_svg_icon "spinner"

register_asset "stylesheets/resource-hub.scss"

module ::DiscourseResourceHub
  PLUGIN_NAME = "discourse-resource-hub"
end

# `lib/` is not autoloaded by Zeitwerk, so these must be required explicitly.
# Anything under `app/` (models, controllers, serializers, jobs) is autoloaded
# and must never be `require_relative`d.
require_relative "lib/discourse_resource_hub/engine"
require_relative "lib/discourse_resource_hub/extensions"
require_relative "lib/discourse_resource_hub/github_client"
require_relative "lib/discourse_resource_hub/github_sync"
require_relative "lib/discourse_resource_hub/guardian"

after_initialize do
  # Mount the engine on the application.
  #
  # `append` — never `draw`. `draw` clears the application's entire route set
  # before rebuilding it, and a plugin's `config/routes.rb` is loaded *before*
  # Discourse's own, so a mount registered with `draw` is wiped moments later.
  # The engine would then be unreachable on any direct visit or full page load
  # while in-app client-side transitions still appeared to work.
  #
  # discourse-cakeday mounts its top-level /cakeday page exactly this way.
  Discourse::Application.routes.append do
    mount ::DiscourseResourceHub::Engine, at: "/resource-hub"
  end

  # Lets the client short-circuit before requesting hub data at all.
  add_to_serializer(:site, :resource_hub_enabled) { SiteSetting.resource_hub_enabled }

  # Discourse rejects any upload whose extension is absent from the core
  # `authorized_extensions` setting, *before* our controller runs. We deliberately
  # do not mutate that global setting from a plugin, so instead we surface a
  # clear warning when the hub's own allow-list is not covered by it.
  DiscourseResourceHub.log_extension_mismatch!
end
