import DiscourseRoute from "discourse/routes/discourse";

// Pass-through parent for `resource-hub.index`, `resource-hub.new` and
// `resource-hub.show`. It owns no model of its own — each child fetches exactly
// what it needs — but it must exist so the children have a parent to render into.
export default class ResourceHubRoute extends DiscourseRoute {}
