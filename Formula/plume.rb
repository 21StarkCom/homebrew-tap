require "download_strategy"

# Fetches a private-repo GitHub Release asset by its API asset URL, adding the
# HOMEBREW_GITHUB_API_TOKEN auth header. Uniquely named so it never collides with
# other formulae in this tap that ship the same pattern.
class PlumePrivateReleaseStrategy < CurlDownloadStrategy
  def _fetch(url:, resolved_url:, timeout:)
    token = ENV["HOMEBREW_GITHUB_API_TOKEN"]
    if token.to_s.empty?
      raise CurlDownloadStrategyError,
            "HOMEBREW_GITHUB_API_TOKEN is required for the private plume tap."
    end

    curl "--location",
         "--header", "Accept: application/octet-stream",
         "--header", "Authorization: token #{token}",
         "--output", temporary_path.to_s,
         url, timeout: timeout
  end
end

# Pure-Go document toolkit: one plume-<format> driver per format (xlsx, docx,
# pdf, pptx). Cross-compiled darwin/arm64 build (Go linker ad-hoc signature).
class Plume < Formula
  desc "Document toolkit CLIs: xlsx, docx, pdf and pptx read/write drivers"
  homepage "https://github.com/21StarkCom/plume"
  # API asset URL (private repo). asset id is release-specific; bump on each release.
  url "https://api.github.com/repos/21StarkCom/plume/releases/assets/559144531",
      using: PlumePrivateReleaseStrategy
  version "0.2.0"
  sha256 "343b324c40649087484b56ec2c267362c30044fe180f9f3082c4f04ce5ddd6c4"
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
