# frozen_string_literal: true

module ::DiscourseResourceHub
  # The Resource Hub keeps its own allow-list of uploadable extensions
  # (`resource_hub_authorized_extensions`). That list is enforced by
  # ResourcesController when a resource is created.
  #
  # However, Discourse validates uploads against the *core*
  # `authorized_extensions` setting first, and rejects anything absent from it
  # before our controller is reached. A plugin mutating that site-wide setting
  # on boot would be surprising and could weaken every other upload path, so
  # instead we detect the gap and tell the admin exactly what to add.
  def self.missing_authorized_extensions
    return [] unless SiteSetting.resource_hub_enabled

    core =
      SiteSetting.authorized_extensions.to_s.split("|").map { |ext| ext.strip.downcase }.reject(&:blank?)

    hub =
      SiteSetting.resource_hub_authorized_extensions.to_s
        .split("|")
        .map { |ext| ext.strip.downcase }
        .reject(&:blank?)

    hub - core
  end

  def self.log_extension_mismatch!
    missing = missing_authorized_extensions
    return if missing.blank?

    Rails.logger.warn(
      "[#{PLUGIN_NAME}] These extensions are allowed by the Resource Hub but not by " \
        "SiteSetting.authorized_extensions, so uploads of those types will be rejected by " \
        "Discourse core: #{missing.join(", ")}. Add them under Admin → Settings → Files, or " \
        "remove them from `resource_hub_authorized_extensions`.",
    )
  end
end
