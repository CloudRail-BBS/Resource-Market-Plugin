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

  # Serializing a SINGLE object needs `root: false`; serializing an array does not.
  #
  # `ApplicationController#serialize_data` behaves differently for the two cases,
  # and the difference is invisible if you only ever test the index:
  #
  #   def serialize_data(obj, serializer, opts = nil)
  #     serializer_opts = { scope: guardian }.merge!(opts || {})
  #     if obj.respond_to?(:to_ary)                      # -> relation / array
  #       serializer_opts[:each_serializer] = serializer
  #       ActiveModel::ArraySerializer.new(obj.to_ary, serializer_opts).as_json
  #     else                                             # -> a single record
  #       serializer.new(obj, serializer_opts).as_json    # <-- adds a root key
  #     end
  #   end
  #
  # `ActiveModel::ArraySerializer` emits a bare array. But
  # `ActiveModel::Serializer#as_json` (AMS 0.8.4) wraps its output in a root:
  #
  #   def as_json(options = {})
  #     if root = options.fetch(:root, @options.fetch(:root, root_name))
  #       hash.merge!(root => serializable_hash)
  #     end
  #   end
  #
  # and `root_name` falls back to the class name, so a single Resource serializes
  # as `{ "resource" => { ...fields } }`. The obvious call therefore double-wraps:
  #
  #   render json: { resource: serialize_data(@resource, ResourceSerializer) }
  #   # => { "resource" => { "resource" => { "id" => 6, ... } } }
  #
  # The index survives because arrays skip the root — so the list page renders and
  # only details break. There, `model.resource.id` is `undefined` (that level holds
  # a nested `resource` hash instead of fields), every URL becomes
  # `/resource-hub/resources/undefined/...`, and it 404s.
  #
  # This mixin gives controllers a `serialize_one` that passes `root: false`, so
  # both shapes behave the same way. Use it for every singleton.
  module SerializationHelpers
    private

    def serialize_one(object, serializer, opts = {})
      serialize_data(object, serializer, opts.merge(root: false))
    end
  end
end
