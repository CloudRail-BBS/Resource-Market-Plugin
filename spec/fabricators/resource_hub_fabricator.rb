# frozen_string_literal: true

Fabricator(:resource_hub_category, class_name: "DiscourseResourceHub::Category") do
  name { sequence(:resource_hub_category_name) { |i| "Category #{i}" } }
  color "E45735"
  icon "box"
  position 0
end

Fabricator(:resource_hub_resource, class_name: "DiscourseResourceHub::Resource") do
  title { sequence(:resource_hub_resource_title) { |i| "Resource #{i}" } }
  user
  status DiscourseResourceHub::Resource::STATUS_APPROVED
end

Fabricator(:resource_hub_comment, class_name: "DiscourseResourceHub::Comment") do
  resource { Fabricate(:resource_hub_resource) }
  user
  raw "A comment"
end
