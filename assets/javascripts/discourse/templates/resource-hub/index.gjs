import { concat, fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { LinkTo } from "@ember/routing";
import RouteTemplate from "ember-route-template";
import { eq } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";
import icon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";
import ResourceHubCard from "../../components/resource-hub-card";

export default RouteTemplate(
  <template>
    <div class="resource-hub">
      <header class="resource-hub__header">
        <div class="resource-hub__heading">
          <h1 class="resource-hub__title">{{@controller.hubTitle}}</h1>
          {{#if @controller.hubDescription}}
            <p class="resource-hub__description">{{@controller.hubDescription}}</p>
          {{/if}}
        </div>
        <div class="resource-hub__header-actions">
          {{#if @controller.canUpload}}
            <LinkTo @route="resource-hub.new" class="btn btn-primary resource-hub__upload-btn">
              {{icon "cloud-arrow-up"}}
              {{i18n "resource_hub.actions.upload"}}
            </LinkTo>
          {{/if}}
          {{#if @controller.canSync}}
            <DButton
              @icon="rotate"
              @action={{@controller.syncGithub}}
              @disabled={{@controller.syncing}}
              @label="resource_hub.actions.sync"
              class="btn-default"
            />
          {{/if}}
        </div>
      </header>

      <div class="resource-hub__toolbar">
        <nav class="resource-hub__tabs">
          {{#each @controller.availableTabs as |tab|}}
            <button
              type="button"
              class="resource-hub__tab {{if (eq @controller.type tab) 'is-active'}}"
              {{on "click" (fn @controller.setType tab)}}
            >
              {{i18n (concat "resource_hub.tabs." tab)}}
            </button>
          {{/each}}
        </nav>
        <div class="resource-hub__controls">
          <input
            type="text"
            value={{@controller.q}}
            placeholder={{i18n "resource_hub.search.placeholder"}}
            class="resource-hub__search"
            {{on "input" @controller.onSearch}}
          />
          <select class="resource-hub__sort" {{on "change" @controller.onSortChange}}>
            <option value="newest" selected={{eq @controller.sort "newest"}}>
              {{i18n "resource_hub.sort.newest"}}
            </option>
            <option value="popular" selected={{eq @controller.sort "popular"}}>
              {{i18n "resource_hub.sort.popular"}}
            </option>
            <option value="name" selected={{eq @controller.sort "name"}}>
              {{i18n "resource_hub.sort.name"}}
            </option>
          </select>
        </div>
      </div>

      {{#if @controller.categories.length}}
        <div class="resource-hub__categories">
          {{#each @controller.categories as |cat|}}
            <button
              type="button"
              class="resource-hub__category {{if (eq @controller.category (concat "" cat.id)) 'is-active'}}"
              {{on "click" (fn @controller.setCategory cat.id)}}
            >
              <span class="resource-hub__category-dot"></span>
              {{cat.name}}
              <span class="resource-hub__category-count">{{cat.resource_count}}</span>
            </button>
          {{/each}}
        </div>
      {{/if}}

      {{#if @controller.isEmpty}}
        <div class="resource-hub__empty">
          {{icon "book-open"}}
          <p>{{i18n @controller.emptyKey}}</p>
        </div>
      {{else}}
        <div class="resource-hub__grid">
          {{#each @controller.resources as |resource|}}
            <ResourceHubCard @resource={{resource}} @onDownload={{@controller.download}} />
          {{/each}}
        </div>
        {{#if @controller.hasMore}}
          <div class="resource-hub__more">
            <DButton
              @action={{@controller.loadMore}}
              @disabled={{@controller.loadingMore}}
              @label="resource_hub.actions.load_more"
              class="btn-default"
            />
          </div>
        {{/if}}
      {{/if}}
    </div>
  </template>
);
