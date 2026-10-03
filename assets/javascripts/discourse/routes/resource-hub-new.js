import Route from "@ember/routing/route";
import { ajax } from "discourse/lib/ajax";

export default class ResourceHubNewRoute extends Route {
  model() {
    return ajax("/resource-hub/resources.json", { data: { per_page: 1 } }).then((result) => ({
      categories: result.categories || [],
      canUpload: result.can_upload,
    }));
  }

  setupController(controller, model) {
    super.setupController(controller, model);
    controller.setProperties({
      categories: model.categories || [],
      canUpload: model.canUpload,
      sourceType: "file",
      title: "",
      description: "",
      version: "",
      tags: "",
      categoryId: null,
      uploadId: null,
      repoFullName: null,
      errorMessage: null,
    });
  }
}
