import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { on } from "@ember/modifier";
import { fn } from "@ember/helper";
import { debounce } from "@ember/runloop";
import { ajax } from "discourse/lib/ajax";
import DButton from "discourse/ui-kit/d-button";
import icon from "discourse/ui-kit/helpers/d-icon";
import I18n, { i18n } from "discourse-i18n";

export default class ResourceHubGithubPicker extends Component {
  @tracked query = "";
  @tracked results = [];
  @tracked loading = false;
  @tracked validating = false;
  @tracked errorMessage = null;
  @tracked selected = null;

  get manualRepo() {
    const input = this.query.trim();
    const fullName = input.replace(/^https:\/\/github\.com\//i, "").replace(/\/$/, "");
    return /^[a-z\d](?:[a-z\d-]{0,38})\/[a-z\d_.-]+$/i.test(fullName)
      ? fullName
      : null;
  }

  @action
  onInput(event) {
    this.query = event.target.value;
    this.selected = null;
    this.args.onSelect?.(null);
    this.errorMessage = null;
    this.results = [];
    if (this.query.trim().length >= 3) {
      debounce(this, this._search, 400);
    }
  }

  async _search() {
    const query = this.query.trim();
    if (query.length < 3 || this.selected) {
      return;
    }
    this.loading = true;
    try {
      const result = await ajax("/resource-hub/github/search.json", { data: { q: query } });
      if (this.query.trim() === query && !this.selected) {
        this.results = result.repositories || [];
      }
    } catch (error) {
      if (this.query.trim() === query && !this.selected) {
        this.errorMessage = I18n.t("resource_hub.errors.github_failed", {
          message: error?.jqXHR?.responseJSON?.errors?.[0] || "",
        });
      }
    } finally {
      this.loading = false;
    }
  }

  @action
  select(repo) {
    this.selected = repo;
    this.results = [];
    this.args.onSelect?.(repo);
  }

  @action
  async useManualInput() {
    const repo = this.manualRepo;
    if (!repo || this.validating) {
      return;
    }
    this.validating = true;
    this.errorMessage = null;
    try {
      const result = await ajax("/resource-hub/github/repo.json", { data: { repo } });
      if (this.manualRepo === repo) {
        this.select(result.repository);
      }
    } catch (error) {
      this.errorMessage = I18n.t("resource_hub.errors.github_failed", {
        message: error?.jqXHR?.responseJSON?.errors?.[0] || "",
      });
    } finally {
      this.validating = false;
    }
  }

  <template>
    <div class="resource-hub-github-picker">
      <div class="resource-hub-github-picker__field">
        <input
          type="text"
          value={{this.query}}
          placeholder={{i18n "resource_hub.form.repo_placeholder"}}
          class="resource-hub-github-picker__input"
          {{on "input" this.onInput}}
        />
        {{#if this.loading}}
          <span class="resource-hub-github-picker__spinner">{{icon "spinner"}}</span>
        {{/if}}
      </div>
      {{#if this.manualRepo}}
        <DButton
          @action={{this.useManualInput}}
          @disabled={{this.validating}}
          @label="resource_hub.actions.link_repo"
          class="btn-default resource-hub-github-picker__manual"
        />
      {{/if}}
      {{#if this.selected}}
        <div class="resource-hub-github-picker__selected">
          {{icon "code-branch"}}
          {{#if this.selected.html_url}}
            <a href={{this.selected.html_url}} target="_blank" rel="noopener noreferrer">
              {{this.selected.full_name}}
            </a>
          {{else}}
            <span>{{this.selected.full_name}}</span>
          {{/if}}
        </div>
      {{/if}}
      {{#if this.errorMessage}}
        <div class="alert alert-error">{{this.errorMessage}}</div>
      {{/if}}
      {{#if this.results.length}}
        <ul class="resource-hub-github-picker__results">
          {{#each this.results as |repo|}}
            <li class="resource-hub-github-picker__result">
              <button type="button" {{on "click" (fn this.select repo)}}>
                <span class="resource-hub-github-picker__repo-name">{{repo.full_name}}</span>
                <span class="resource-hub-github-picker__repo-desc">{{repo.description}}</span>
                <span class="resource-hub-github-picker__repo-meta">
                  {{icon "star"}} {{repo.stars}}
                  {{#if repo.language}}
                    <span class="resource-hub-github-picker__lang">{{repo.language}}</span>
                  {{/if}}
                </span>
              </button>
            </li>
          {{/each}}
        </ul>
      {{/if}}
    </div>
  </template>
}
