# frozen_string_literal: true

# Ad-hoc-signed macOS build of muxctl, the control-API CLI of the mux-control repo. This
# formula was named hermod up to 0.52.0 (STARK-19541): it keeps a `hermod` link to muxctl.
class Muxctl < Formula
  desc "TypeScript CLI + engine for the cmux control API: spawn/split, todos, orphans"
  homepage "https://github.com/21StarkCom/homebrew-tap"
  # Source release repo: 21StarkCom/mux-control
  url "https://github.com/21StarkCom/homebrew-tap/releases/download/muxctl-v0.55.0/muxctl_v0.55.0_darwin_arm64.zip"
  version "0.55.0"
  sha256 "c9d75e6ce0f8e7ec4d8f11487a71b245d9c614190ac13c3412bca9f3be3a1942"

  # muxctl finds a repo's checkout with `urd repos get`. Tap-qualified: a bare name resolves
  # to homebrew/core first, and is ambiguous when another tap ships a `urd`.
  depends_on "21starkcom/tap/urd"
  depends_on arch: :arm64
  depends_on macos: :golden_gate # the release Mac's Homebrew bun builds it for macOS 27.0; bare symbol == ">="

  def install
    bin.install "muxctl"
    bin.install_symlink "muxctl" => "hermod"
  end

  test do
    assert_equal "muxctl v#{version}", shell_output("#{bin}/muxctl version").strip
    assert_equal "muxctl v#{version}", shell_output("#{bin}/hermod version").strip
  end
end
