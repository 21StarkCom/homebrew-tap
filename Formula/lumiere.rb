# frozen_string_literal: true

# Signed (Developer ID) + notarized macOS build of the 21Stark visual-media
# toolkit: the `lumiere` dispatcher, and a `lumiere-<tool>` command for each tool.
class Lumiere < Formula
  desc "Visual-media CLI toolkit: image gen/edit, SVG, video, brand icons"
  homepage "https://github.com/21StarkCom/lumiere"
  # API asset URL (private repo). asset id is release-specific; bump on each release.
  # Homebrew's own lookup: HOMEBREW_GITHUB_API_TOKEN, else `gh auth token`, else a keychain token.
  # Its sandboxed build, test and postinstall workers reload this file where gh cannot read its
  # config. They never download (the brew process fetched first), so they skip the lookup.
  worker = %w[build.rb test.rb postinstall.rb].any? { |w| $PROGRAM_NAME == (HOMEBREW_LIBRARY_PATH/w).to_s }
  token = worker ? "" : GitHub::API.credentials.to_s.strip
  url "https://api.github.com/repos/21StarkCom/lumiere/releases/assets/755925631",
      headers: ["Accept: application/octet-stream", "Authorization: token #{token}"]
  version "0.11.0"
  sha256 "b4dc5ee297568935b76276e7d1a12af78cf07bd539499a9264f83b749d06e604"
  if token.empty? && !worker
    raise CurlDownloadStrategyError.new(
      stable.url,
      "This private tap needs a GitHub token with contents:read access: " \
      "run `gh auth login` with Homebrew's gh (`brew install gh`), or set HOMEBREW_GITHUB_API_TOKEN.",
    )
  end

  depends_on arch: :arm64
  depends_on macos: :tahoe # the cgo (ONNX) tools are built for macOS 26.0; bare symbol == ">="

  def install
    # The dispatcher ships as plain `lumiere`, which "lumiere-*" does not match.
    bin.install Dir["lumiere", "lumiere-*"]
    # A multi-call zip (STARK-18421) holds two binaries: lumiere-onnx, which holds the tools
    # that link ONNX Runtime, and lumiere, which holds the rest. Each runs the tool its argv[0]
    # names, so a link lumiere-<tool> to the binary that holds the tool is its command. A zip
    # with a file for each tool (v0.9.0 and before) gets no link.
    onnx = bin/"lumiere-onnx"
    Utils.safe_popen_read(bin/"lumiere", "tools").split.each do |tool|
      command = bin/"lumiere-#{tool}"
      next if command.exist? || command.symlink?

      # lumiere-onnx exits 0 only for a tool it holds. For any other tool it fails.
      holder = (onnx.exist? && quiet_system(onnx, tool, "-version")) ? onnx : bin/"lumiere"
      bin.install_symlink holder.basename => command.basename
    end
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/lumiere --version")
    # Each tool of the manifest runs as lumiere-<tool>: its own file, or a link that install made.
    tools = shell_output("#{bin}/lumiere tools").split
    assert_includes tools, "upscale"
    tools.each do |tool|
      assert_match(/\Alumiere-#{Regexp.escape(tool)} v?#{Regexp.escape(version.to_s)}$/,
                   shell_output("#{bin}/lumiere-#{tool} -version"))
    end
    # The dispatcher runs a tool by its first argument, and finds an ONNX tool beside itself.
    assert_match(/\Alumiere-svg v?#{Regexp.escape(version.to_s)}$/, shell_output("#{bin}/lumiere svg -version"))
    assert_match(/\Alumiere-upscale v?#{Regexp.escape(version.to_s)}$/,
                 shell_output("#{bin}/lumiere upscale -version"))
    # One cgo (ONNX) tool, offline. Launching it fails if it was built for a newer macOS than
    # this one (v0.4.0 shipped minos 27.0, STARK-8882). Without the library-validation
    # entitlement it can't load the ONNX Runtime it downloads (v0.1.1-v0.4.1, STARK-9716).
    # The check reads the binary that holds lumiere-upscale: the file, or the link's target.
    assert_match "com.apple.security.cs.disable-library-validation",
                 shell_output("codesign -d --entitlements - --xml #{(bin/"lumiere-upscale").realpath} 2>&1")
  end
end
