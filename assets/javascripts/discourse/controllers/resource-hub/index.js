import Controller from "@ember/controller";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { i18n as I18n } from "discourse-i18n";
import { resourceSegment } from "../../lib/resource-hub-resource-key";

export default class ResourceHubIndexController extends Controller {
  @service router;
  @service currentUser;
  @service siteSettings;

  queryParams = ["type", "q", "sort", "category", "page"];

  tabs = ["all", "files", "repositories", "mine"];

  @tracked type = "all";
  @tracked q = "";
  @tracked sort = "newest";
  @tracked category = null;
  @tracked page = 1;

  @tracked resources = [];
  @tracked categories = [];
  @tracked meta = {};
  @tracked canUpload = false;
  @tracked canReview = false;
  @tracked hubTitle = "Resource Hub";
  @tracked hubDescription = "";
  @tracked syncing = false;
  @tracked loadingMore = false;

  get isEmpty() {
    return this.resources.length === 0;
  }

  // The sync endpoint is staff-only, so the button must be gated on the
  // permission the server reported rather than merely being signed in.
  get canSync() {
    return this.canReview && this.siteSettings.resource_hub_github_enabled;
  }

  get availableTabs() {
    return this.currentUser ? this.tabs : this.tabs.filter((tab) => tab !== "mine");
  }

  get hasMore() {
    return Boolean(this.meta?.has_more);
  }

  get emptyKey() {
    const valid = ["all", "files", "repositories", "mine"];
    return `resource_hub.empty.${valid.includes(this.type) ? this.type : "all"}`;
  }

  @action
  setType(type) {
    this.type = type;
    this.page = 1;
  }

  @action
  setSort(sort) {
    this.sort = sort;
    this.page = 1;
  }

  @action
  onSortChange(event) {
    this.setSort(event.target.value);
  }

  @action
  setCategory(categoryId) {
    this.category = this.category === String(categoryId) ? null : String(categoryId);
    this.page = 1;
  }

  @action
  onSearch(event) {
    this.q = event.target.value;
    this.page = 1;
  }

  @action
  loadMore() {
    if (this.loadingMore || !this.hasMore) {
      return;
    }
    this.loadingMore = true;
    this.page = (this.meta.page || 1) + 1;
  }

  @action
  async syncGithub() {
    this.syncing = true;
    try {
      await ajax("/resource-hub/github/repo/sync.json", { type: "POST" });
      this.router.refresh();
    } catch (error) {
      popupAjaxError(error);
    } finally {
      this.syncing = false;
    }
  }

  @action
  async download(resource) {
    const key = resourceSegment(resource);
    if (!key) {
      popupAjaxError(new Error(I18n.t("resource_hub.errors.generic")));
      return;
    }

    try {
      const result = await ajax(`/resource-hub/resources/${key}/download.json`, {
        type: "POST",
      });
      if (result.redirect_url) {
        window.open(result.redirect_url, "_blank", "noopener,noreferrer");
      }
      resource.download_count = (resource.download_count || 0) + 1;
    } catch (error) {
      popupAjaxError(error);
    }
  }
}
