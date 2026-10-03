import Controller from "@ember/controller";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { i18n } from "discourse-i18n";

export default class ResourceHubShowController extends Controller {
  @service router;
  @service dialog;
  @service currentUser;

  @tracked resource = null;
  @tracked comments = [];
  @tracked canManage = false;
  @tracked newComment = "";
  @tracked posting = false;

  @action
  async download() {
    try {
      const result = await ajax(`/resource-hub/resources/${this.resource.id}/download.json`, {
        type: "POST",
      });
      if (result.redirect_url) {
        window.open(result.redirect_url, "_blank", "noopener,noreferrer");
      }
      this.resource.download_count = (this.resource.download_count || 0) + 1;
    } catch (error) {
      popupAjaxError(error);
    }
  }

  @action
  onCommentInput(event) {
    this.newComment = event.target.value;
  }

  @action
  async postComment() {
    if (!this.newComment.trim()) {
      return;
    }
    this.posting = true;
    try {
      const result = await ajax(`/resource-hub/resources/${this.resource.id}/comments.json`, {
        type: "POST",
        data: { raw: this.newComment },
      });
      this.comments = [...this.comments, result.comment];
      this.newComment = "";
    } catch (error) {
      popupAjaxError(error);
    } finally {
      this.posting = false;
    }
  }

  @action
  async deleteComment(comment) {
    if (!(await this.dialog.deleteConfirm({ message: i18n("resource_hub.comments.confirm_delete") }))) {
      return;
    }
    try {
      await ajax(
        `/resource-hub/resources/${this.resource.id}/comments/${comment.id}.json`,
        { type: "DELETE" }
      );
      this.comments = this.comments.filter((c) => c.id !== comment.id);
    } catch (error) {
      popupAjaxError(error);
    }
  }

  @action
  async deleteResource() {
    if (!(await this.dialog.deleteConfirm({ message: i18n("resource_hub.confirm_delete") }))) {
      return;
    }
    try {
      await ajax(`/resource-hub/resources/${this.resource.id}.json`, { type: "DELETE" });
      this.router.transitionTo("resource-hub.index");
    } catch (error) {
      popupAjaxError(error);
    }
  }
}
