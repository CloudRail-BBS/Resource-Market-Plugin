# frozen_string_literal: true

RSpec.describe DiscourseResourceHub::ResourcesController do
  fab!(:user)
  fab!(:other_user, :user)
  fab!(:admin)
  fab!(:category) { Fabricate(:resource_hub_category) }

  before { SiteSetting.resource_hub_enabled = true }

  def approved_resource(attrs = {})
    Fabricate(:resource_hub_resource, category: category, **attrs)
  end

  describe "#index" do
    it "requires the plugin to be enabled" do
      SiteSetting.resource_hub_enabled = false
      get "/resource-hub/resources.json"
      expect(response.status).to eq(404)
    end

    it "returns approved resources to anonymous visitors" do
      resource = approved_resource
      Fabricate(:resource_hub_resource, status: DiscourseResourceHub::Resource::STATUS_PENDING)

      get "/resource-hub/resources.json"

      expect(response.status).to eq(200)
      expect(response.parsed_body["resources"].map { |r| r["id"] }).to contain_exactly(resource.id)
    end

    it "hides other members' pending submissions" do
      approved_resource(user: other_user, status: DiscourseResourceHub::Resource::STATUS_PENDING)

      get "/resource-hub/resources.json"

      expect(response.parsed_body["resources"]).to be_empty
    end

    it "includes the caller's own pending submissions when mine=true" do
      mine = approved_resource(user: user, status: DiscourseResourceHub::Resource::STATUS_PENDING)
      approved_resource(user: other_user, status: DiscourseResourceHub::Resource::STATUS_PENDING)

      sign_in(user)
      get "/resource-hub/resources.json", params: { mine: "true" }

      expect(response.parsed_body["resources"].map { |r| r["id"] }).to contain_exactly(mine.id)
    end

    it "filters by category" do
      other_category = Fabricate(:resource_hub_category)
      wanted = approved_resource
      approved_resource(category: other_category)

      get "/resource-hub/resources.json", params: { category_id: category.id }

      expect(response.parsed_body["resources"].map { |r| r["id"] }).to contain_exactly(wanted.id)
    end

    it "reports pagination metadata" do
      3.times { approved_resource }

      get "/resource-hub/resources.json", params: { per_page: 2 }

      expect(response.parsed_body["meta"]).to include("total" => 3, "page" => 1, "has_more" => true)
      expect(response.parsed_body["resources"].size).to eq(2)
    end
  end

  describe "#show" do
    it "resolves a resource by slug" do
      resource = approved_resource(title: "Data Explorer")

      get "/resource-hub/resources/#{resource.slug}.json"

      expect(response.status).to eq(200)
      expect(response.parsed_body.dig("resource", "id")).to eq(resource.id)
    end

    it "still resolves a resource by numeric id" do
      resource = approved_resource

      get "/resource-hub/resources/#{resource.id}.json"

      expect(response.status).to eq(200)
      expect(response.parsed_body.dig("resource", "id")).to eq(resource.id)
    end

    it "forbids reading someone else's pending resource" do
      resource =
        approved_resource(user: other_user, status: DiscourseResourceHub::Resource::STATUS_PENDING)
      sign_in(user)

      get "/resource-hub/resources/#{resource.slug}.json"

      expect(response.status).to eq(403)
    end

    it "allows staff to read a pending resource" do
      resource =
        approved_resource(user: other_user, status: DiscourseResourceHub::Resource::STATUS_PENDING)
      sign_in(admin)

      get "/resource-hub/resources/#{resource.slug}.json"

      expect(response.status).to eq(200)
      expect(response.parsed_body["can_manage"]).to eq(true)
    end
  end

  describe "#create" do
    let(:upload) do
      Fabricate(:upload, user: user, original_filename: "archive.zip", extension: "zip")
    end

    it "requires login" do
      post "/resource-hub/resources.json", params: { title: "x", upload_id: upload.id }
      expect(response.status).to eq(403)
    end

    it "rejects an upload owned by another member" do
      foreign = Fabricate(:upload, user: other_user, original_filename: "a.zip", extension: "zip")
      sign_in(user)

      post "/resource-hub/resources.json", params: { title: "Mine", upload_id: foreign.id }

      expect(response.status).to eq(403)
    end

    it "rejects an extension outside the hub allow-list" do
      SiteSetting.resource_hub_authorized_extensions = "zip"
      bad = Fabricate(:upload, user: user, original_filename: "payload.exe", extension: "exe")
      sign_in(user)

      post "/resource-hub/resources.json", params: { title: "Bad", upload_id: bad.id }

      expect(response.status).to eq(400)
    end

    it "creates an approved resource for staff" do
      sign_in(admin)

      post "/resource-hub/resources.json",
           params: {
             title: "Discourse archive",
             upload_id: upload.id,
             category_id: category.id,
           }

      expect(response.status).to eq(201)
      expect(response.parsed_body.dig("resource", "status")).to eq(
        DiscourseResourceHub::Resource::STATUS_APPROVED,
      )
    end

    it "queues a resource for review when the author is not auto-approved" do
      group = Fabricate(:group)
      SiteSetting.resource_hub_auto_approve_groups = group.id.to_s
      sign_in(user)

      post "/resource-hub/resources.json", params: { title: "Pending", upload_id: upload.id }

      expect(response.status).to eq(201)
      expect(response.parsed_body.dig("resource", "status")).to eq(
        DiscourseResourceHub::Resource::STATUS_PENDING,
      )
    end

    it "rejects a request with neither an upload nor a repository" do
      sign_in(user)

      post "/resource-hub/resources.json", params: { title: "Nothing" }

      expect(response.status).to eq(422)
    end
  end

  describe "#destroy" do
    it "allows the author to delete their resource" do
      resource = approved_resource(user: user)
      sign_in(user)

      delete "/resource-hub/resources/#{resource.id}.json"

      expect(response.status).to eq(200)
      expect(DiscourseResourceHub::Resource.exists?(resource.id)).to eq(false)
    end

    it "forbids deleting someone else's resource" do
      resource = approved_resource(user: other_user)
      sign_in(user)

      delete "/resource-hub/resources/#{resource.id}.json"

      expect(response.status).to eq(403)
      expect(DiscourseResourceHub::Resource.exists?(resource.id)).to eq(true)
    end
  end

  describe "#review" do
    it "forbids a regular member from approving their own submission" do
      resource =
        approved_resource(user: user, status: DiscourseResourceHub::Resource::STATUS_PENDING)
      sign_in(user)

      patch "/resource-hub/resources/#{resource.id}/review.json", params: { status: "approved" }

      expect(response.status).to eq(403)
      expect(resource.reload.status).to eq(DiscourseResourceHub::Resource::STATUS_PENDING)
    end

    it "lets staff approve a submission" do
      resource =
        approved_resource(user: user, status: DiscourseResourceHub::Resource::STATUS_PENDING)
      sign_in(admin)

      patch "/resource-hub/resources/#{resource.id}/review.json", params: { status: "approved" }

      expect(response.status).to eq(200)
      expect(resource.reload.status).to eq(DiscourseResourceHub::Resource::STATUS_APPROVED)
    end

    it "rejects an unknown status value" do
      resource = approved_resource
      sign_in(admin)

      patch "/resource-hub/resources/#{resource.id}/review.json", params: { status: "banana" }

      expect(response.status).to eq(422)
    end
  end

  describe "#download" do
    it "returns a storage URL for a file resource and counts the download" do
      upload = Fabricate(:upload, user: user, original_filename: "archive.zip", extension: "zip")
      resource = approved_resource(user: user, upload: upload)
      sign_in(user)

      post "/resource-hub/resources/#{resource.id}/download.json"

      expect(response.status).to eq(200)
      expect(response.parsed_body["redirect_url"]).to be_present
      expect(resource.reload.download_count).to eq(1)
    end

    it "returns the canonical repository URL for a repository resource" do
      resource =
        approved_resource(user: user, repo_full_name: "discourse/discourse", repo_url: "https://github.com/discourse/discourse")
      sign_in(user)

      post "/resource-hub/resources/#{resource.id}/download.json"

      expect(response.parsed_body["redirect_url"]).to eq("https://github.com/discourse/discourse")
    end

    it "does not increment the counter when tracking is disabled" do
      SiteSetting.resource_hub_count_downloads = false
      upload = Fabricate(:upload, user: user, original_filename: "archive.zip", extension: "zip")
      resource = approved_resource(user: user, upload: upload)
      sign_in(user)

      post "/resource-hub/resources/#{resource.id}/download.json"

      expect(resource.reload.download_count).to eq(0)
    end
  end
end
