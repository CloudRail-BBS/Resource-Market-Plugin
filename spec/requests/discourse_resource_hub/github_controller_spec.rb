# frozen_string_literal: true

RSpec.describe DiscourseResourceHub::GithubController do
  fab!(:user)
  fab!(:admin)
  fab!(:resource) do
    Fabricate(
      :resource_hub_resource,
      repo_full_name: "discourse/discourse",
      repo_url: "https://github.com/discourse/discourse",
    )
  end

  before do
    SiteSetting.resource_hub_enabled = true
    SiteSetting.resource_hub_github_enabled = true
  end

  describe "#search" do
    it "requires login so anonymous traffic cannot drain the shared API quota" do
      get "/resource-hub/github/search.json", params: { q: "discourse" }
      expect(response.status).to eq(403)
    end

    it "returns a projected payload rather than raw upstream JSON" do
      sign_in(user)
      stub_request(:get, %r{https://api\.github\.com/search/repositories}).to_return(
        status: 200,
        body: {
          total_count: 1,
          items: [
            {
              full_name: "discourse/discourse",
              html_url: "https://github.com/discourse/discourse",
              description: "A platform for community discussion",
              stargazers_count: 42,
              forks_count: 7,
              language: "Ruby",
              license: {
                spdx_id: "GPL-2.0",
              },
            },
          ],
        }.to_json,
        headers: {
          "Content-Type" => "application/json",
        },
      )

      get "/resource-hub/github/search.json", params: { q: "discourse" }

      expect(response.status).to eq(200)
      repo = response.parsed_body["repositories"].first
      expect(repo["full_name"]).to eq("discourse/discourse")
      expect(repo["stars"]).to eq(42)
      expect(repo["license"]).to eq("GPL-2.0")
    end
  end

  describe "#show" do
    it "requires login" do
      get "/resource-hub/github/repo.json", params: { repo: "discourse/discourse" }
      expect(response.status).to eq(403)
    end

    it "rejects a reference that is not a GitHub repository" do
      sign_in(user)

      get "/resource-hub/github/repo.json", params: { repo: "not-a-repo" }

      expect(response.status).to eq(422)
    end
  end

  describe "#link" do
    it "requires login" do
      post "/resource-hub/github/repo.json", params: { repo: "discourse/discourse" }
      expect(response.status).to eq(403)
    end

    it "refuses to re-link a repository that already has a resource" do
      sign_in(user)

      post "/resource-hub/github/repo.json", params: { repo: "discourse/discourse" }

      expect(response.status).to eq(422)
      expect(response.parsed_body["errors"].first).to include("already linked")
    end
  end

  describe "#sync" do
    it "forbids non-staff members" do
      sign_in(user)

      post "/resource-hub/github/repo/sync.json"

      expect(response.status).to eq(403)
    end

    it "refreshes repositories for staff" do
      sign_in(admin)
      stub_request(:get, "https://api.github.com/repos/discourse/discourse").to_return(
        status: 200,
        body: {
          full_name: "discourse/discourse",
          html_url: "https://github.com/discourse/discourse",
          stargazers_count: 1234,
          forks_count: 10,
        }.to_json,
        headers: {
          "Content-Type" => "application/json",
        },
      )
      stub_request(:get, %r{https://api\.github\.com/repos/discourse/discourse/releases}).to_return(
        status: 200,
        body: [].to_json,
        headers: {
          "Content-Type" => "application/json",
        },
      )

      post "/resource-hub/github/repo/sync.json"

      expect(response.status).to eq(200)
      expect(response.parsed_body["synced"]).to eq(1)
      expect(resource.reload.repo_stars).to eq(1234)
    end
  end

  describe "#unlink" do
    it "refuses to detach the repository when there is no uploaded file to serve" do
      sign_in(admin)

      delete "/resource-hub/github/repo.json", params: { resource_id: resource.id }

      expect(response.status).to eq(400)
      expect(resource.reload.repo_full_name).to eq("discourse/discourse")
    end
  end
end
