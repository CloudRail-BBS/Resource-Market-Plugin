import DiscourseRoute from "discourse/routes/discourse";
import { ajax } from "discourse/lib/ajax";
import { action } from "@ember/object";
import { service } from "@ember/service";

export default class ResourceHubIndexRoute extends DiscourseRoute {
  @service router;
  @service siteSettings;

  queryParams = {
    type: { refreshModel: true },
    q: { refreshModel: true },
    sort: { refreshModel: true },
    category: { refreshModel: true },
    page: { refreshModel: true },
  };

  model(params) {
    const queryKey = JSON.stringify([params.type, params.q, params.sort, params.category]);
    return ajax("/resource-hub/resources.json", {
      data: {
        type: params.type === "mine" ? undefined : params.type || undefined,
        mine: params.type === "mine" ? "true" : undefined,
        q: params.q || undefined,
        sort: params.sort || undefined,
        category_id: params.category || undefined,
        page: params.page || 1,
      },
    }).then((result) => ({ ...result, queryKey }));
  }

  setupController(controller, model) {
    super.setupController(controller, model);
    const append =
      model.meta?.page > 1 &&
      model.meta.page === controller.meta?.page + 1 &&
      this._listQueryKey === model.queryKey;
    this._listQueryKey = model.queryKey;
    controller.setProperties({
      resources: append
        ? [...controller.resources, ...(model.resources || [])]
        : model.resources || [],
      categories: model.categories || [],
      meta: model.meta || {},
      loadingMore: false,
      canUpload: model.can_upload,
      canReview: model.can_review,
      hubTitle: model.title,
      hubDescription: model.description,
    });
  }

  resetController(controller, isExiting) {
    if (isExiting) {
      this._listQueryKey = null;
      controller.setProperties({
        type: "all",
        q: "",
        sort: "newest",
        category: null,
        page: 1,
        loadingMore: false,
      });
    }
  }

  @action
  error(error) {
    this.controller?.set("loadingMore", false);
    if (error?.jqXHR?.status === 404) {
      this.router.replaceWith("/404");
      return false;
    }
    throw error;
  }
}
