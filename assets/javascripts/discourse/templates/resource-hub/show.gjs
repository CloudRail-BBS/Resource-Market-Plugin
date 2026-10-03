import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { LinkTo } from "@ember/routing";
import { htmlSafe } from "@ember/template";
import RouteTemplate from "ember-route-template";
import DButton from "discourse/ui-kit/d-button";
import icon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

export default RouteTemplate(
  <template>
    <div class="resource-hub resource-hub--detail">
      {{#if @controller.resource}}
        <header class="resource-hub__header">
          <div class="resource-hub__heading">
            <LinkTo @route="resource-hub.index" class="resource-hub-detail__back">
              {{icon "arrow-left"}} {{i18n "resource_hub.title"}}
            </LinkTo>
            <h1 class="resource-hub__title">{{@controller.resource.title}}</h1>
            {{#if @controller.resource.category_name}}
              <span class="resource-hub-detail__category">
                {{@controller.resource.category_name}}
              </span>
            {{/if}}
          </div>
          <div class="resource-hub__header-actions">
            {{#if @controller.currentUser}}
              <DButton
                @icon={{if @controller.resource.external "code-branch" "file-arrow-down"}}
                @action={{@controller.download}}
                @label="resource_hub.actions.download"
                class="btn-primary"
              />
            {{/if}}
            {{#if @controller.resource.github}}
              <a
                href={{@controller.resource.github.html_url}}
                target="_blank"
                rel="noopener noreferrer"
                class="btn btn-default"
              >
                {{icon "code-branch"}}
                {{i18n "resource_hub.actions.visit"}}
              </a>
            {{/if}}
            {{#if @controller.canManage}}
              <DButton
                @icon="trash-can"
                @action={{@controller.deleteResource}}
                @label="resource_hub.actions.delete"
                class="btn-danger"
              />
            {{/if}}
          </div>
        </header>

        <div class="resource-hub-detail__body">
          <div class="resource-hub-detail__main">
            {{#if @controller.resource.description}}
              <p class="resource-hub-detail__description">{{@controller.resource.description}}</p>
            {{/if}}
            <dl class="resource-hub-detail__facts">
              <div>
                <dt>{{i18n "resource_hub.fields.uploaded_by"}}</dt>
                <dd>{{@controller.resource.username}}</dd>
              </div>
              {{#if @controller.resource.version}}
                <div>
                  <dt>{{i18n "resource_hub.fields.version"}}</dt>
                  <dd>{{@controller.resource.version}}</dd>
                </div>
              {{/if}}
              <div>
                <dt>{{i18n "resource_hub.fields.downloads"}}</dt>
                <dd>{{@controller.resource.download_count}}</dd>
              </div>
              {{#if @controller.resource.file_name}}
                <div>
                  <dt>{{i18n "resource_hub.form.file"}}</dt>
                  <dd>{{@controller.resource.file_name}}</dd>
                </div>
              {{/if}}
            </dl>

            {{#if @controller.resource.repository}}
              <section class="resource-hub-detail__repo">
                <h2>{{i18n "resource_hub.types.repository"}}</h2>
                <div class="resource-hub-detail__repo-stats">
                  <span>{{icon "star"}} {{@controller.resource.github.stars}}</span>
                  <span>{{icon "code-branch"}} {{@controller.resource.github.forks}}</span>
                  {{#if @controller.resource.github.language}}
                    <span>{{@controller.resource.github.language}}</span>
                  {{/if}}
                  {{#if @controller.resource.github.license}}
                    <span>{{@controller.resource.github.license}}</span>
                  {{/if}}
                </div>
                {{#if @controller.resource.github.releases.length}}
                  <h3>{{i18n "resource_hub.repo.releases"}}</h3>
                  <ul class="resource-hub-detail__releases">
                    {{#each @controller.resource.github.releases as |release|}}
                      <li>
                        {{#if release.html_url}}
                          <a href={{release.html_url}} target="_blank" rel="noopener noreferrer">
                            {{release.name}}
                          </a>
                        {{else}}
                          {{release.name}}
                        {{/if}}
                        <span class="resource-hub-detail__release-date">{{release.published_at}}</span>
                        {{#each release.assets as |asset|}}
                          <span class="resource-hub-detail__asset">{{asset.name}}</span>
                        {{/each}}
                      </li>
                    {{/each}}
                  </ul>
                {{else}}
                  <p class="resource-hub-detail__muted">{{i18n "resource_hub.repo.no_releases"}}</p>
                {{/if}}
              </section>
            {{/if}}

            <section class="resource-hub-detail__comments">
              <h2>{{i18n "resource_hub.comments.title"}}</h2>
              {{#if @controller.comments.length}}
                <ul class="resource-hub-comments">
                  {{#each @controller.comments as |comment|}}
                    <li class="resource-hub-comment">
                      <div class="resource-hub-comment__header">
                        <span class="resource-hub-comment__author">{{comment.username}}</span>
                        <span class="resource-hub-comment__date">{{comment.created_at}}</span>
                      </div>
                      <div class="resource-hub-comment__body">{{htmlSafe comment.cooked}}</div>
                      {{#if comment.can_delete}}
                        <DButton
                          @icon="trash-can"
                          @action={{fn @controller.deleteComment comment}}
                          @ariaLabel="resource_hub.comments.delete"
                          class="btn-flat btn-danger btn-small"
                        />
                      {{/if}}
                    </li>
                  {{/each}}
                </ul>
              {{else}}
                <p class="resource-hub-detail__muted">{{i18n "resource_hub.comments.empty"}}</p>
              {{/if}}
              {{#if @controller.currentUser}}
                <div class="resource-hub-comment-form">
                  <textarea
                    value={{@controller.newComment}}
                    rows="3"
                    placeholder={{i18n "resource_hub.comments.placeholder"}}
                    class="resource-hub-form__textarea"
                    {{on "input" @controller.onCommentInput}}
                  ></textarea>
                  <DButton
                    @action={{@controller.postComment}}
                    @disabled={{@controller.posting}}
                    @label="resource_hub.comments.submit"
                    class="btn-primary"
                  />
                </div>
              {{/if}}
            </section>
          </div>
        </div>
      {{else}}
        <div class="resource-hub__empty">
          {{icon "circle-info"}}
          <p>{{i18n "resource_hub.errors.generic"}}</p>
        </div>
      {{/if}}
    </div>
  </template>
);
