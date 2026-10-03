import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import RouteTemplate from "ember-route-template";
import DButton from "discourse/ui-kit/d-button";
import icon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";
import ResourceHubGithubPicker from "../../components/resource-hub-github-picker";
import ResourceHubUploader from "../../components/resource-hub-uploader";

export default RouteTemplate(
  <template>
    <div class="resource-hub resource-hub--form">
      <header class="resource-hub__header">
        <div class="resource-hub__heading">
          <h1 class="resource-hub__title">{{i18n "resource_hub.form.title"}}</h1>
        </div>
        <DButton @icon="xmark" @action={{@controller.cancel}} class="btn-flat" />
      </header>

      {{#if @controller.canUpload}}
        <form class="resource-hub-form" {{on "submit" @controller.submit}}>
          <div class="resource-hub-form__source-toggle">
            <button
              type="button"
              class="resource-hub-form__source-btn {{if @controller.isFileSource 'is-active'}}"
              {{on "click" (fn @controller.setSourceType "file")}}
            >
              {{icon "cloud-arrow-up"}}
              {{i18n "resource_hub.types.file"}}
            </button>
            <button
              type="button"
              class="resource-hub-form__source-btn {{unless @controller.isFileSource 'is-active'}}"
              {{on "click" (fn @controller.setSourceType "repo")}}
            >
              {{icon "code-branch"}}
              {{i18n "resource_hub.types.repository"}}
            </button>
          </div>

          <div class="resource-hub-form__field">
            <label for="resource-hub-title">{{i18n "resource_hub.form.name"}}</label>
            <input
              id="resource-hub-title"
              type="text"
              value={{@controller.title}}
              placeholder={{i18n "resource_hub.form.name_placeholder"}}
              class="resource-hub-form__input"
              {{on "input" @controller.onTitle}}
            />
          </div>
          <div class="resource-hub-form__field">
            <label for="resource-hub-description">{{i18n "resource_hub.form.description"}}</label>
            <textarea
              id="resource-hub-description"
              value={{@controller.description}}
              placeholder={{i18n "resource_hub.form.description_placeholder"}}
              class="resource-hub-form__textarea"
              rows="4"
              {{on "input" @controller.onDescription}}
            ></textarea>
          </div>
          <div class="resource-hub-form__row">
            <div class="resource-hub-form__field">
              <label for="resource-hub-category">{{i18n "resource_hub.form.category"}}</label>
              <select
                id="resource-hub-category"
                class="resource-hub-form__select"
                {{on "change" @controller.onCategory}}
              >
                <option value=""></option>
                {{#each @controller.categories as |cat|}}
                  <option value={{cat.id}}>{{cat.name}}</option>
                {{/each}}
              </select>
            </div>
            <div class="resource-hub-form__field">
              <label for="resource-hub-version">{{i18n "resource_hub.form.version"}}</label>
              <input
                id="resource-hub-version"
                type="text"
                value={{@controller.version}}
                class="resource-hub-form__input"
                placeholder="1.0.0"
                {{on "input" @controller.onVersion}}
              />
            </div>
          </div>
          <div class="resource-hub-form__field">
            <label for="resource-hub-tags">{{i18n "resource_hub.form.tags"}}</label>
            <input
              id="resource-hub-tags"
              type="text"
              value={{@controller.tags}}
              class="resource-hub-form__input"
              placeholder={{i18n "resource_hub.form.tags_placeholder"}}
              {{on "input" @controller.onTags}}
            />
          </div>

          {{#if @controller.isFileSource}}
            <div class="resource-hub-form__field">
              <label>{{i18n "resource_hub.form.file"}}</label>
              <ResourceHubUploader @onUploadChanged={{@controller.onUploadChanged}} />
            </div>
          {{else}}
            <div class="resource-hub-form__field">
              <label>{{i18n "resource_hub.form.repo_url"}}</label>
              <ResourceHubGithubPicker @onSelect={{@controller.onRepoSelected}} />
            </div>
          {{/if}}

          {{#if @controller.errorMessage}}
            <div class="alert alert-error">{{@controller.errorMessage}}</div>
          {{/if}}
          <div class="resource-hub-form__actions">
            <DButton
              @type="submit"
              @disabled={{@controller.submitting}}
              @label="resource_hub.form.submit"
              class="btn-primary"
            />
            <DButton
              @action={{@controller.cancel}}
              @label="resource_hub.actions.cancel"
              class="btn-flat"
            />
          </div>
        </form>
      {{else}}
        <div class="resource-hub__empty">
          {{icon "circle-info"}}
          <p>{{i18n "resource_hub.errors.forbidden"}}</p>
        </div>
      {{/if}}
    </div>
  </template>
);
