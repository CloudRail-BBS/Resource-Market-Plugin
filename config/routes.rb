# frozen_string_literal: true

# The engine's own routes.
DiscourseResourceHub::Engine.routes.draw do
  get "/" => "pages#index"
  get "/new" => "pages#index"
  get "/r/:slug" => "pages#index"

  get "/resources" => "resources#index"
  get "/resources/:id" => "resources#show"
  post "/resources" => "resources#create"
  put "/resources/:id" => "resources#update"
  patch "/resources/:id/review" => "resources#review"
  delete "/resources/:id" => "resources#destroy"
  post "/resources/:id/download" => "resources#download"
  get "/resources/:id/comments" => "comments#index"
  post "/resources/:id/comments" => "comments#create"
  delete "/resources/:id/comments/:comment_id" => "comments#destroy"

  get "/github/search" => "github#search"
  get "/github/repo" => "github#show"
  post "/github/repo" => "github#link"
  post "/github/repo/sync" => "github#sync"
  delete "/github/repo" => "github#unlink"
end

# Mount the engine onto the application.
#
# This MUST stay in this file, and it must be `draw` — NOT
# `Discourse::Application.routes.append` from a plugin's `after_initialize`.
#
# Rails loads a plugin's `config/routes.rb` through the engine routes reloader
# while the application's route set is still open. By the time `after_initialize`
# runs, the route set has already been finalised, and `append` blocks are only
# evaluated by `finalize!` — so a mount registered there is **never applied**.
# The engine is silently not mounted and every URL under /resource-hub 404s with
# "The requested URL or resource could not be found."
#
# `draw` is safe here even though it calls `clear!`: Rails has clearing disabled
# at this point (`@disable_clear_and_finalize`), which is why
# discourse-data-explorer mounts its engine with exactly this form.
Discourse::Application.routes.draw do
  mount ::DiscourseResourceHub::Engine, at: "/resource-hub"
end
