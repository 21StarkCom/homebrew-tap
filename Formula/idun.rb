# frozen_string_literal: true

# Ad-hoc-signed macOS build of the idun personal-ops maintenance CLI.
class Idun < Formula
  desc "Personal-ops CLI for GitHub identities, seat rotation, and housekeeping"
  homepage "https://github.com/21StarkCom/idun"
  # API asset URL (private repo). asset id is release-specific; bump on each release.
  token = ENV.fetch("HOMEBREW_GITHUB_API_TOKEN", "").strip
  url "https://api.github.com/repos/21StarkCom/idun/releases/assets/584063554",
      headers: ["Accept: application/octet-stream", "Authorization: token #{token}"]
  version "0.81.0"
  sha256 "b361b7f5b319715f5c9f70dffb9e234fa5418b89947639476a43840083d5ad2b"
  if token.empty?
    raise CurlDownloadStrategyError.new(
      stable.url, "HOMEBREW_GITHUB_API_TOKEN is required for this private tap (GitHub contents:read access)."
    )
  end

  depends_on arch: :arm64
  depends_on :macos

  def install
    bin.install "idun"
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/idun --version")
  end
end
