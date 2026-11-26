# frozen_string_literal: true

# Pure-Go document toolkit: one plume-<format> driver per format (xlsx, docx,
# pdf, pptx). Cross-compiled darwin/arm64 build (Go linker ad-hoc signature).
class Plume < Formula
  desc "Document toolkit CLIs: xlsx, docx, pdf and pptx read/write drivers"
  homepage "https://github.com/21StarkCom/homebrew-tap"
  # Source release repo: 21StarkCom/plume
  url "https://github.com/21StarkCom/homebrew-tap/releases/download/plume-v0.12.0/plume_v0.12.0_darwin_arm64.tar.gz"
  version "0.12.0"
  sha256 "3bbfa8027451721bf816dc9fa804ca1207f220206264906be56d0d7600216649"

  depends_on arch: :arm64
  depends_on :macos

  def install
    # The plume dispatcher, a bare name that plume-* does not match, and the drivers, globbed
    # so the install tracks the tool set as new plume-* drivers are added. Dir drops the
    # dispatcher from a release that does not ship it.
    bin.install Dir["plume", "plume-*"]
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/plume-pdf version")
  end
end
