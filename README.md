# Discourse Resource Hub

A resource centre for Discourse: upload files, download community artefacts, and
link GitHub repositories so their stars, issues and releases stay in sync.

## Features

- **Upload** — drag and drop files with a per-extension and per-size allow-list.
- **Download** — a download endpoint that counts downloads and returns a storage
  URL (signed when secure uploads are in use).
- **GitHub integration** — search GitHub, link a repository, and import its
  metadata (stars, forks, issues, language, licence) plus releases and release
  assets. A scheduled job keeps them fresh.
- **Categories & tags** — seeded categories plus free-form topics, filterable
  from the hub toolbar.
- **Comments** — Markdown comments, cooked through `PrettyText` so the stored
  HTML is sanitised before it reaches the client.
- **Moderation** — submissions from members outside the auto-approve groups stay
  pending until a staff member approves them.

## Requirements

Discourse **3.4.0** or newer. The frontend is written entirely in `.gjs`
single-file components; `.hbs` templates are removed after the 2026.7 ESR, so
this plugin does not use them.

## Installation

Pin the destination directory — it must match the plugin name declared in
`plugin.rb`:

```yaml
hooks:
  after_code:
    - exec:
        cd: $home/plugins
        cmd:
          - git clone https://github.com/your-org/discourse-resource-hub.git discourse-resource-hub
```

Then rebuild:

```bash
./launcher rebuild app
```

For local development, clone into `plugins/` and restart `bin/ember-cli -u`.

## Configuration

All settings live under **Admin → Settings → Plugins**.

| Setting | Type | Default | Description |
| --- | --- | --- | --- |
| `resource_hub_enabled` | boolean | `true` | Master switch. |
| `resource_hub_nav_link` | boolean | `true` | Show a link in the main navigation. |
| `resource_hub_title` | string | `Resource Hub` | Heading on the hub page. |
| `resource_hub_description` | string | — | Subheading on the hub page. |
| `resource_hub_max_file_size_kb` | integer | `20480` | Max upload size, in KB. |
| `resource_hub_authorized_extensions` | string | archives, docs, images, media | Additional allow-list; see below. |
| `resource_hub_count_downloads` | boolean | `true` | Serve downloads through the hub so they are counted. |
| `resource_hub_upload_allowed_groups` | group list | *(any logged in user)* | Who may upload. |
| `resource_hub_auto_approve_groups` | group list | `staff` | Who publishes without review. |
| `resource_hub_github_enabled` | boolean | `true` | Enable GitHub integration. |
| `resource_hub_github_token` | string (secret) | — | Read-only token; raises the API limit from 60 to 5000 req/h. |
| `resource_hub_github_sync_hours` | integer | `6` | Background sync interval (`0` disables). |
| `resource_hub_github_import_releases` | boolean | `true` | Import release assets during sync. |
| `resource_hub_github_max_releases` | integer | `5` | Releases imported per repo, per sync. |
| `resource_hub_github_topics` | string | `discourse-plugin\|discourse-theme\|discourse` | Topics kept when importing a repo. |

### Uploads: two allow-lists, not one

Discourse validates every upload against the **core** `authorized_extensions`
setting and rejects anything absent from it *before* the plugin's controller
runs. `resource_hub_authorized_extensions` is an **additional** restriction on
top of that: an upload must satisfy both.

This plugin deliberately does **not** rewrite the site-wide
`authorized_extensions` setting on boot, because that would silently widen every
other upload path on the forum. Instead, on boot it logs a warning listing any
extension the hub allows but core does not:

```
[discourse-resource-hub] These extensions are allowed by the Resource Hub but not by
SiteSetting.authorized_extensions, so uploads of those types will be rejected by
Discourse core: 7z, rar. Add them under Admin → Settings → Files, or remove them from
`resource_hub_authorized_extensions`.
```

To distribute executables or installers, widen **both** settings.

### A note on the GitHub token

Unauthenticated GitHub API calls are limited to **60 requests per hour per IP**,
which a busy forum exhausts quickly. Create a read-only personal access token
(classic tokens need no scopes; fine-grained tokens only need *Public
repositories → read*) and set `resource_hub_github_token`.

## Architecture

```
discourse-resource-hub/
├── plugin.rb                       # manifest + post-boot registration
├── app/                            # Zeitwerk-autoloaded: never require_relative
│   ├── controllers/discourse_resource_hub/
│   │   ├── pages_controller.rb       # serves the SPA shell for direct visits
│   │   ├── resources_controller.rb   # index/show/create/update/review/destroy/download
│   │   ├── comments_controller.rb
│   │   └── github_controller.rb      # search/show/link/sync/unlink
│   ├── jobs/scheduled/discourse_resource_hub/sync_github_repos.rb
│   ├── models/discourse_resource_hub/{resource,category,comment}.rb
│   ├── serializers/discourse_resource_hub/{resource,category,comment}_serializer.rb
│   └── views/discourse_resource_hub/pages/index.html.erb
├── assets/
│   ├── javascripts/discourse/
│   │   ├── api-initializers/init-resource-hub.js
│   │   ├── components/            # resource-hub-{card,uploader,github-picker}.gjs
│   │   ├── controllers/
│   │   ├── routes/
│   │   ├── templates/resource-hub/{index,new,show}.gjs
│   │   └── resource-hub-route-map.js
│   └── stylesheets/resource-hub.scss
├── config/
│   ├── routes.rb                   # engine routes, mounted at /resource-hub
│   ├── settings.yml
│   └── locales/{server,client}.en.yml
├── db/migrate/                     # resources, categories, comments, category seed
├── lib/discourse_resource_hub/     # explicitly required from plugin.rb
│   ├── engine.rb                   # Rails::Engine + Zeitwerk autoloading
│   ├── extensions.rb               # authorised-extension diagnostics
│   ├── github_client.rb            # GitHub REST wrapper, caching, error mapping
│   ├── github_sync.rb              # maps GitHub payloads onto Resource records
│   └── guardian.rb                 # upload / moderation policy
└── spec/                           # RSpec: models, lib, requests
```

`app/` is owned by Zeitwerk and is **never** `require_relative`d; `lib/` is not
autoloaded and **must** be. Mixing the two makes Zeitwerk and the explicit
require fight over the same constants and fails the whole boot, so `lib/` is
deliberately kept out of `config.autoload_paths`. The trade-off is that changes
under `lib/` need a server restart instead of hot reloading.

### Request flow

1. `resource-hub-route-map.js` registers `/resource-hub` in the Ember router.
2. A direct visit or refresh hits `PagesController`, which skips `check_xhr` and
   renders the application shell; Ember then boots and takes over routing.
3. Data always comes from the JSON API — e.g. `GET /resource-hub/resources.json`
   dispatches to `ResourcesController#index`.
4. Controllers serialise with `ActiveModel::Serializer` (Discourse injects the
   current `Guardian` as the serializer `scope`).
5. Ember renders the matching `.gjs` template.

### API endpoints

| Method | Path | Notes |
| --- | --- | --- |
| `GET` | `/resource-hub/resources.json` | `type`, `q`, `sort`, `category_id`, `topic`, `page`, `per_page`, `mine` |
| `GET` | `/resource-hub/resources/:id.json` | Accepts a **slug or** a numeric id |
| `POST` | `/resource-hub/resources.json` | `upload_id` **or** `repo_url` |
| `PUT` | `/resource-hub/resources/:id.json` | Author or staff |
| `PATCH` | `/resource-hub/resources/:id/review.json` | Staff only: `status=approved\|rejected` |
| `DELETE` | `/resource-hub/resources/:id.json` | Author or staff |
| `POST` | `/resource-hub/resources/:id/download.json` | Returns `redirect_url` |
| `GET`/`POST` | `/resource-hub/resources/:id/comments.json` | |
| `DELETE` | `/resource-hub/resources/:id/comments/:comment_id.json` | |
| `GET` | `/resource-hub/github/search.json?q=` | Login required, rate limited |
| `GET` | `/resource-hub/github/repo.json?repo=owner/name` | |
| `POST` | `/resource-hub/github/repo.json` | Link a repository |
| `POST` | `/resource-hub/github/repo/sync.json` | Staff only |
| `DELETE` | `/resource-hub/github/repo.json` | Detach a repository |

## Security notes

- **Uploads** go through Discourse's own `POST /uploads.json`, so CSRF
  protection, storage backends (local or S3) and the `Upload` record behave
  exactly as elsewhere in the app. The hub additionally re-checks the extension
  and size server-side, and rejects an `upload_id` belonging to another member.
- **Downloads** never accept a caller-supplied URL. A repository resolves to its
  canonical GitHub URL; a file resolves through `Discourse.store.url_for`, which
  produces a signed URL when secure uploads are enabled.
- **Visibility** — pending and rejected resources are readable only by their
  author and staff, on every endpoint including comments.
- **Review transitions** are staff-only, so an author cannot approve their own
  submission.
- **GitHub endpoints all require login**, because they spend the site's shared
  API quota. Search is additionally rate limited per user.
- **Repository linking** is gated on the same permission as uploading, and
  refuses to adopt a repository that already has a resource owned by someone
  else.
- **Comments** are cooked with `PrettyText`, which sanitises the HTML before it
  is stored.

## Development

```bash
# Ruby syntax
find . -name '*.rb' -exec ruby -c {} \;

# Ruby specs (from a Discourse checkout, with this repo in plugins/)
bin/rspec plugins/discourse-resource-hub/spec
```

The frontend targets Discourse's current `main`, which means:

- `.gjs` single-file components (`class X { <template>…</template> }`).
- `RouteTemplate` from `ember-route-template` for route templates.
- Imports from `discourse/ui-kit/d-button`, `discourse/ui-kit/helpers/d-icon`
  and `discourse/truth-helpers` (the paths core uses after the ui-kit
  consolidation). The older `discourse/components/…` paths still resolve through
  compatibility shims.

## Licence

MIT
