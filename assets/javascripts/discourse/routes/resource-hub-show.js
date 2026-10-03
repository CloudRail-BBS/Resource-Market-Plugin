import Route from "@ember/routing/route";
import { ajax } from "discourse/lib/ajax";
import { action } from "@ember/object";
import { service } from "@ember/service";

export default class ResourceHubShowRoute extends Route {
  @service router;

  model(params) {
    return ajax(`/resource-hub/resources/${encodeURIComponent(params.slug)}.json`);
  }

  setupController(controller, model) {
    super.setupController(controller, model);
    controller.setProperties({
      resource: model.resource,
      comments: model.comments || [],
      canManage: model.can_manage,
    });
  }

  @action
  error(error) {
    if (error?.jqXHR?.status === 404) {
      this.router.replaceWith("/404");
      return false;
    }
    throw error;
  }
}
