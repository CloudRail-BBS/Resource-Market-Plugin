# frozen_string_literal: true

# The engine's own routes.
#
# The engine is mounted onto the application from `plugin.rb`
# (`Discourse::Application.routes.append` inside `after_initialize`), NOT from
# here. That is the pattern discourse-cakeday uses for its top-level /cakeday
# page, and it matters:
#
# `Discourse::Application.routes.draw` CLEARS the application's whole route set
# before rebuilding it. A plugin's `config/routes.rb` is loaded *before*
# Discourse's own, so anything mounted with `draw` is wiped when Discourse's
# routes file is loaded afterwards — `/resource-hub` then 404s on any direct
# visit or full page load (which is exactly what clicking a nav bar item does,
# since those render a plain <a href>), while in-app client-side transitions
# still appear to work. `append` adds to the route set instead of replacing it.
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
