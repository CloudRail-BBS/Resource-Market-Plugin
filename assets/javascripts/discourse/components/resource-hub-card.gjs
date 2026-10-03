import Component from "@glimmer/component";
import { action } from "@ember/object";
import DButton from "discourse/ui-kit/d-button";
import icon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

export default class ResourceHubCard extends Component {
  get resource() {
    return this.args.resource;
  }

  get isRepository() {
    return Boolean(this.resource.repository);
  }

  get badgeLabel() {
    return this.isRepository ? "resource_hub.types.repository" : "resource_hub.types.file";
  }

  get detailHref() {
    return `/resource-hub/r/${encodeURIComponent(this.resource.slug)}`;
  }

  get statusLabel() {
    switch (this.resource.status) {
      case 0:
        return "resource_hub.status.pending";
      case 2:
        return "resource_hub.status.rejected";
      default:
        return null;
    }
  }

  get humanSize() {
    const bytes = this.resource.file_size;
    if (!bytes) {
      return null;
    }

    const units = ["B", "KB", "MB", "GB"];
    let value = bytes;
    let index = 0;
    while (value >= 1024 && index < units.length - 1) {
      value /= 1024;
      index += 1;
    }
    return `${value.toFixed(index === 0 ? 0 : 1)} ${units[index]}`;
  }

  @action
  onDownload(event) {
    event.preventDefault();
    event.stopPropagation();
    this.args.onDownload?.(this.resource);
  }

  <template>
    <article class="resource-hub-card">
      <div class="resource-hub-card__top">
        <span class="resource-hub-card__type">
          {{#if this.isRepository}}
            {{icon "code-branch"}}
          {{else}}
            {{icon "paperclip"}}
          {{/if}}
          {{i18n this.badgeLabel}}
        </span>
        {{#if this.resource.category_name}}
          <span class="resource-hub-card__category">{{this.resource.category_name}}</span>
        {{/if}}
      </div>

      {{#if this.statusLabel}}
        <div class="resource-hub-card__status">{{i18n this.statusLabel}}</div>
      {{/if}}

      <h3 class="resource-hub-card__title">
        <a href={{this.detailHref}}>{{this.resource.title}}</a>
      </h3>

      {{#if this.resource.description}}
        <p class="resource-hub-card__description">{{this.resource.description}}</p>
      {{/if}}

      {{#if this.isRepository}}
        {{#if this.resource.github}}
          <div class="resource-hub-card__repo-meta">
            <span>{{icon "star"}} {{this.resource.github.stars}}</span>
            <span>{{icon "code-branch"}} {{this.resource.github.forks}}</span>
            {{#if this.resource.github.language}}
              <span>{{this.resource.github.language}}</span>
            {{/if}}
            {{#if this.resource.github.license}}
              <span>{{this.resource.github.license}}</span>
            {{/if}}
          </div>
        {{/if}}
      {{else}}
        <div class="resource-hub-card__file-meta">
          {{#if this.resource.file_name}}
            <span class="resource-hub-card__file-name">{{this.resource.file_name}}</span>
          {{/if}}
          {{#if this.humanSize}}<span>{{this.humanSize}}</span>{{/if}}
          {{#if this.resource.version}}
            <span>{{i18n "resource_hub.fields.version"}} {{this.resource.version}}</span>
          {{/if}}
        </div>
      {{/if}}

      {{#if this.resource.topics}}
        <div class="resource-hub-card__topics">
          {{#each this.resource.topics as |topic|}}
            <span class="resource-hub-card__topic">{{topic}}</span>
          {{/each}}
        </div>
      {{/if}}

      <div class="resource-hub-card__footer">
        <span class="resource-hub-card__author">{{this.resource.username}}</span>
        <span class="resource-hub-card__counts">
          {{icon "download"}} {{this.resource.download_count}}
        </span>
        <DButton
          @icon={{if this.isRepository "code-branch" "file-arrow-down"}}
          @action={{this.onDownload}}
          @ariaLabel="resource_hub.actions.download"
          class="btn-flat btn-small resource-hub-card__download"
        />
      </div>
    </article>
  </template>
}
