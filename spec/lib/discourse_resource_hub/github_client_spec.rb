# frozen_string_literal: true

RSpec.describe DiscourseResourceHub::GithubClient do
  describe ".normalize_repo" do
    it "accepts the canonical owner/repo form" do
      expect(described_class.normalize_repo("discourse/discourse")).to eq("discourse/discourse")
    end

    it "accepts a full GitHub URL" do
      expect(described_class.normalize_repo("https://github.com/discourse/discourse")).to eq(
        "discourse/discourse",
      )
    end

    it "strips a trailing .git suffix" do
      expect(described_class.normalize_repo("https://github.com/discourse/discourse.git")).to eq(
        "discourse/discourse",
      )
    end

    it "ignores trailing path segments such as /tree/main" do
      expect(
        described_class.normalize_repo("https://github.com/discourse/discourse/tree/main/plugins"),
      ).to eq("discourse/discourse")
    end

    it "rejects non-GitHub hosts" do
      expect(described_class.normalize_repo("https://gitlab.com/discourse/discourse")).to be_nil
    end

    it "rejects a bare owner with no repository" do
      expect(described_class.normalize_repo("discourse")).to be_nil
    end

    it "rejects blank input" do
      expect(described_class.normalize_repo("")).to be_nil
      expect(described_class.normalize_repo(nil)).to be_nil
    end
  end

  describe ".get" do
    it "memoises successful responses instead of re-requesting GitHub" do
      described_class.clear_cache!
      stub_request(:get, "https://api.github.com/repos/discourse/discourse").to_return(
        status: 200,
        body: { full_name: "discourse/discourse" }.to_json,
        headers: {
          "Content-Type" => "application/json",
        },
      )

      first = described_class.repository("discourse/discourse")
      second = described_class.repository("discourse/discourse")

      expect(first["full_name"]).to eq("discourse/discourse")
      expect(second).to eq(first)
      expect(WebMock).to have_requested(:get, "https://api.github.com/repos/discourse/discourse").once
    end

    it "raises a not_found error for a 404" do
      described_class.clear_cache!
      stub_request(:get, "https://api.github.com/repos/discourse/nope").to_return(status: 404, body: "{}")

      expect { described_class.repository("discourse/nope") }.to raise_error(
        DiscourseResourceHub::GithubClient::Error,
      ) { |error| expect(error.not_found?).to eq(true) }
    end

    it "flags a rate limited response" do
      described_class.clear_cache!
      stub_request(:get, "https://api.github.com/repos/discourse/discourse").to_return(
        status: 403,
        body: { message: "rate limited" }.to_json,
        headers: {
          "x-ratelimit-remaining" => "0",
        },
      )

      expect { described_class.repository("discourse/discourse") }.to raise_error(
        DiscourseResourceHub::GithubClient::Error,
      ) { |error| expect(error.rate_limited?).to eq(true) }
    end
  end
end
