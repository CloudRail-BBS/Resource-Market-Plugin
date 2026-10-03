import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { on } from "@ember/modifier";
import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import DButton from "discourse/ui-kit/d-button";
import icon from "discourse/ui-kit/helpers/d-icon";
import I18n from "discourse-i18n";

export default class ResourceHubUploader extends Component {
  @service siteSettings;

  @tracked uploadId = null;
  @tracked fileName = null;
  @tracked fileSize = null;
  @tracked uploading = false;
  @tracked uploadProgress = 0;
  @tracked errorMessage = null;

  get maxFileSizeKB() {
    return Number(this.siteSettings.resource_hub_max_file_size_kb) || 20480;
  }

  get authorizedExtensions() {
    return (this.siteSettings.resource_hub_authorized_extensions || "")
      .split("|")
      .map((ext) => ext.trim().toLowerCase())
      .filter(Boolean);
  }

  get acceptAttribute() {
    return this.authorizedExtensions.map((ext) => `.${ext}`).join(",");
  }

  get hint() {
    return I18n.t("resource_hub.form.drop_hint");
  }

  @action
  onFileSelected(event) {
    const file = event.target.files?.[0];
    if (file) {
      this.uploadFile(file);
    }
  }

  @action
  onDrop(event) {
    event.preventDefault();
    const file = event.dataTransfer?.files?.[0];
    if (file) {
      this.uploadFile(file);
    }
  }

  @action
  onDragOver(event) {
    event.preventDefault();
  }

  @action
  removeFile() {
    this.uploadId = null;
    this.fileName = null;
    this.fileSize = null;
    this.uploadProgress = 0;
    this.errorMessage = null;
    this.args.onUploadChanged?.(null);
  }

  async uploadFile(file) {
    if (this.uploading) {
      return;
    }

    this.errorMessage = null;
    if (!this._validate(file)) {
      return;
    }

    this.uploading = true;
    this.uploadProgress = 0;
    this.args.onUploadChanged?.(null);

    const data = new FormData();
    data.append("file", file);
    data.append("upload_type", "resource_hub");

    try {
      // Discourse's ajax wrapper applies the current session's CSRF token via
      // its same-origin jQuery prefilter (including multipart requests).
      const upload = await ajax("/uploads.json", {
        type: "POST",
        data,
        processData: false,
        contentType: false,
        xhr: () => {
          const request = new XMLHttpRequest();
          request.upload.addEventListener("progress", (event) => {
            if (event.lengthComputable) {
              this.uploadProgress = Math.round((event.loaded / event.total) * 100);
            }
          });
          return request;
        },
      });

      this.uploadId = upload.id;
      this.fileName = upload.original_filename || file.name;
      this.fileSize = upload.filesize || file.size;
      this.args.onUploadChanged?.(upload);
    } catch (error) {
      this.errorMessage = this._errorMessageFor(error);
    } finally {
      this.uploading = false;
    }
  }

  _validate(file) {
    const extension = file.name.split(".").pop()?.toLowerCase();
    if (extension && !this.authorizedExtensions.includes(extension)) {
      this.errorMessage = I18n.t("resource_hub.errors.upload_failed", {
        message: `.${extension}`,
      });
      return false;
    }

    if (file.size > this.maxFileSizeKB * 1024) {
      this.errorMessage = I18n.t("resource_hub.errors.upload_failed", {
        message: `${(this.maxFileSizeKB / 1024).toFixed(1)} MB`,
      });
      return false;
    }

    return true;
  }

  _errorMessageFor(error) {
    const fromServer =
      error?.jqXHR?.responseJSON?.errors?.[0] || error?.errors?.[0] || error?.message;

    return I18n.t("resource_hub.errors.upload_failed", {
      message: fromServer || I18n.t("resource_hub.errors.generic"),
    });
  }

  <template>
    <div class="resource-hub-uploader">
      {{#if this.fileName}}
        <div class="resource-hub-uploader__selected">
          <span class="resource-hub-uploader__icon">{{icon "paperclip"}}</span>
          <span class="resource-hub-uploader__name">{{this.fileName}}</span>
          <DButton
            @icon="trash-can"
            @action={{this.removeFile}}
            @title="resource_hub.form.remove_file"
            class="btn-flat btn-danger"
          />
        </div>
      {{else}}
        <label
          class="resource-hub-uploader__dropzone"
          {{on "dragover" this.onDragOver}}
          {{on "drop" this.onDrop}}
        >
          <input
            type="file"
            class="resource-hub-uploader__input"
            accept={{this.acceptAttribute}}
            disabled={{this.uploading}}
            aria-label={{this.hint}}
            {{on "change" this.onFileSelected}}
          />
          <span class="resource-hub-uploader__dropzone-icon">{{icon "cloud-arrow-up"}}</span>
          <span class="resource-hub-uploader__dropzone-text">{{this.hint}}</span>
          <span class="resource-hub-uploader__dropzone-hint">{{this.acceptAttribute}}</span>
        </label>
      {{/if}}
      {{#if this.uploading}}
        <progress
          class="resource-hub-uploader__progress"
          value={{this.uploadProgress}}
          max="100"
          aria-label={{this.hint}}
        ></progress>
      {{/if}}
      {{#if this.errorMessage}}
        <div class="resource-hub-uploader__error alert alert-error">{{this.errorMessage}}</div>
      {{/if}}
    </div>
  </template>
}
