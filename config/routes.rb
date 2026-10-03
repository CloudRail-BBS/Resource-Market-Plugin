# frozen_string_literal: true

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

Discourse::Application.routes.draw do
  mount ::DiscourseResourceHub::Engine, at: "/resource-hub"
end
