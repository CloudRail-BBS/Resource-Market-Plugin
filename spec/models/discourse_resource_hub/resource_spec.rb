# frozen_string_literal: true

RSpec.describe DiscourseResourceHub::Resource do
  fab!(:user)
  fab!(:category) { Fabricate(:resource_hub_category) }

  describe "slug generation" do
    it "derives a slug from the title" do
      resource = Fabricate(:resource_hub_resource, title: "Discourse Data Explorer")
      expect(resource.slug).to eq("discourse-data-explorer")
    end

    it "keeps slugs unique" do
      first = Fabricate(:resource_hub_resource, title: "Same Title")
      second = Fabricate(:resource_hub_resource, title: "Same Title")

      expect(second.slug).not_to eq(first.slug)
      expect(second.slug).to start_with("same-title")
    end

    it "falls back to a generic slug when the title has no word characters" do
      resource = Fabricate(:resource_hub_resource, title: "!!!")
      expect(resource.slug).to be_present
    end
  end

  describe "topics" do
    it "normalises, de-duplicates and caps the list" do
      resource =
        Fabricate(
          :resource_hub_resource,
          topics: ["Ruby", "ruby", "  Discourse  ", "", *10.times.map { |i| "topic-#{i}" }],
        )

      expect(resource.topics).to eq(["ruby", "discourse", "topic-0", "topic-1", "topic-2", "topic-3", "topic-4", "topic-5"])
      expect(resource.topics.size).to eq(described_class::MAX_TOPICS)
    end
  end

  describe "validation" do
    it "requires a title" do
      resource = Fabricate.build(:resource_hub_resource, title: nil)
      expect(resource).not_to be_valid
      expect(resource.errors[:title]).to be_present
    end

    it "rejects a malformed repository name" do
      resource = Fabricate.build(:resource_hub_resource, repo_full_name: "just-a-name")
      expect(resource).not_to be_valid
      expect(resource.errors[:repo_full_name]).to be_present
    end

    it "accepts an owner/repo repository name" do
      resource = Fabricate.build(:resource_hub_resource, repo_full_name: "discourse/discourse")
      expect(resource).to be_valid
    end

    it "does not allow two resources to claim the same repository" do
      Fabricate(:resource_hub_resource, repo_full_name: "discourse/discourse")
      duplicate = Fabricate.build(:resource_hub_resource, repo_full_name: "discourse/discourse")

      expect(duplicate).not_to be_valid
    end
  end

  describe "classification" do
    it "treats an upload-backed record as a file" do
      upload = Fabricate(:upload, user: user)
      resource = Fabricate(:resource_hub_resource, upload: upload)

      expect(resource.file?).to eq(true)
      expect(resource.repository?).to eq(false)
      expect(resource.external?).to eq(false)
    end

    it "treats a repository with no local asset as external" do
      resource = Fabricate(:resource_hub_resource, repo_full_name: "discourse/discourse")

      expect(resource.repository?).to eq(true)
      expect(resource.external?).to eq(true)
      expect(resource.download_path).to eq(resource.repo_url)
    end

    it "reports status predicates" do
      approved = Fabricate(:resource_hub_resource)
      pending = Fabricate(:resource_hub_resource, status: described_class::STATUS_PENDING)

      expect(approved.approved?).to eq(true)
      expect(approved.pending?).to eq(false)
      expect(pending.pending?).to eq(true)
    end
  end

  describe "scopes" do
    it "separates approved from pending" do
      approved = Fabricate(:resource_hub_resource)
      Fabricate(:resource_hub_resource, status: described_class::STATUS_PENDING)

      expect(described_class.approved).to contain_exactly(approved)
    end

    it "orders popular resources by download count" do
      low = Fabricate(:resource_hub_resource, download_count: 1)
      high = Fabricate(:resource_hub_resource, download_count: 99)

      expect(described_class.popular.first).to eq(high)
      expect(described_class.popular.last).to eq(low)
    end
  end

  describe "#count_resources on the category" do
    it "only counts approved resources" do
      Fabricate(:resource_hub_resource, category: category)
      Fabricate(:resource_hub_resource, category: category, status: described_class::STATUS_PENDING)

      category.count_resources

      expect(category.reload.resource_count).to eq(1)
    end
  end
end
