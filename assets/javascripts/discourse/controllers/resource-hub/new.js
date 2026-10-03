import Controller from "@ember/controller";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import I18n from "discourse-i18n";

export default class ResourceHubNewController extends Controller {
  @service router;
  @service dialog;

  @tracked categories = [];
  @tracked canUpload = false;

  @tracked sourceType = "file";
  @tracked title = "";
  @tracked description = "";
  @tracked version = "";
  @tracked tags = "";
  @tracked categoryId = null;
  @tracked uploadId = null;
  @tracked repoFullName = null;

  @tracked submitting = false;
  @tracked errorMessage = null;

  get isFileSource() {
    return this.sourceType === "file";
  }

  get canSubmit() {
    if (!this.title.trim() || this.submitting) {
      return false;
    }
    return this.isFileSource ? Boolean(this.uploadId) : Boolean(this.repoFullName);
  }

  @action
  setSourceType(type) {
    if (this.sourceType === type) {
      return;
    }
    this.sourceType = type;
    this.uploadId = null;
    this.repoFullName = null;
    this.errorMessage = null;
  }

  @action
  onTitle(event) {
    this.title = event.target.value;
  }

  @action
  onDescription(event) {
    this.description = event.target.value;
  }

  @action
  onVersion(event) {
    this.version = event.target.value;
  }

  @action
  onTags(event) {
    this.tags = event.target.value;
  }

  @action
  onCategory(event) {
    this.categoryId = event.target.value;
  }

  @action
  onUploadChanged(upload) {
    this.uploadId = upload?.id || null;
  }

  @action
  onRepoSelected(repo) {
    this.repoFullName = repo?.full_name || null;
  }

  @action
  async submit(event) {
    event.preventDefault();

    if (!this.title.trim()) {
      this.errorMessage = I18n.t("resource_hub.errors.title_required");
      return;
    }
    if (!this.canSubmit) {
      this.errorMessage = I18n.t(
        this.isFileSource ? "resource_hub.errors.file_required" : "resource_hub.errors.repo_required"
      );
      return;
    }

    this.submitting = true;
    this.errorMessage = null;

    try {
      await ajax("/resource-hub/resources.json", {
        type: "POST",
        data: {
          title: this.title.trim(),
          description: this.description.trim(),
          version: this.version.trim() || undefined,
          tags: this.tags,
          category_id: this.categoryId || undefined,
          upload_id: this.isFileSource ? this.uploadId : undefined,
          repo_url: this.isFileSource ? undefined : this.repoFullName,
        },
      });
      this.router.transitionTo("resource-hub.index");
    } catch (error) {
      this.errorMessage =
        error?.jqXHR?.responseJSON?.errors?.[0] || I18n.t("resource_hub.errors.generic");
    } finally {
      this.submitting = false;
    }
  }

  @action
  cancel() {
    this.router.transitionTo("resource-hub.index");
  }
}
