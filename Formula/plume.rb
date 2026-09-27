# frozen_string_literal: true

# Pure-Go document toolkit: one plume-<format> driver per format (xlsx, docx,
# pdf, pptx). Cross-compiled darwin/arm64 build (Go linker ad-hoc signature).
class Plume < Formula
  desc "Document toolkit CLIs: xlsx, docx, pdf and pptx read/write drivers"
  homepage "https://github.com/21StarkCom/plume"
  # API asset URL (private repo). asset id is release-specific; bump on each release.
  token = ENV.fetch("HOMEBREW_GITHUB_API_TOKEN", "").strip
  url "https://api.github.com/repos/21StarkCom/plume/releases/assets/593320290",
      headers: ["Accept: application/octet-stream", "Authorization: token #{token}"]
  version "0.5.1"
  sha256 "21de3997e76908ba67c16f6f24ea32b83a843fc5bdf8a3ec1b96c50d7a5f1bfc"
  if token.empty?
    raise CurlDownloadStrategyError.new(
      stable.url, "HOMEBREW_GITHUB_API_TOKEN is required for this private tap (GitHub contents:read access)."
    )
  end

  depends_on arch: :arm64
  depends_on :macos

  def install
    # Globbed so the install tracks the tool set as new plume-* drivers are added.
    bin.install Dir["plume-*"]
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/plume-pdf version")
  end
end
