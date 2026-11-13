# frozen_string_literal: true

# macOS build of `floorplan`, the fleet's C4 design tool on LikeC4 (`21StarkCom/floorplan`, the
# `packages/floorplan` package). node ESM, like `librarian`: the zip ships a `pnpm deploy` tree
# (bin, kit, dist + node_modules). It has no Mach-O of its own; its Mach-Os are npm's ad-hoc
# linker-signed native prebuilds. Released from `floorplan-v*` tags by `scripts/release-floorplan.sh`.
class Floorplan < Formula
  desc "C4 design tool of the 21Stark fleet, built on LikeC4"
  homepage "https://github.com/21StarkCom/floorplan"
  # API asset URL (private repo). asset id is release-specific; bump on each release.
  # Homebrew's own lookup: HOMEBREW_GITHUB_API_TOKEN, else `gh auth token`, else a keychain token.
  # Its sandboxed build, test and postinstall workers reload this file where gh cannot read its
  # config. They never download (the brew process fetched first), so they skip the lookup.
  # So does its fix_linkage worker (sandbox_operation.rb), which reloads it for preserve_rpath.
  worker = %w[build.rb test.rb postinstall.rb sandbox_operation.rb].any? do |w|
    $PROGRAM_NAME == (HOMEBREW_LIBRARY_PATH/w).to_s
  end
  token = worker ? "" : GitHub::API.credentials.to_s.strip
  url "https://api.github.com/repos/21StarkCom/floorplan/releases/assets/742851644",
      headers: ["Accept: application/octet-stream", "Authorization: token #{token}"]
  version "0.10.0"
  sha256 "ba16b062cd68552656d8d49511a66a1884ccccad07a3f6f1394c907b78034890"
  if token.empty? && !worker
    raise CurlDownloadStrategyError.new(
      stable.url,
      "This private tap needs a GitHub token with contents:read access: " \
      "run `gh auth login` with Homebrew's gh (`brew install gh`), or set HOMEBREW_GITHUB_API_TOKEN.",
    )
  end

  depends_on arch: :arm64 # the zip vendors darwin-arm64 native prebuilds (esbuild, rollup, …)
  depends_on :macos
  depends_on "node" # floorplan is node ESM; the keg node runs bin/floorplan.mjs

  # Homebrew renames each dylib in the keg to its long `opt` path, and fails the install when
  # that name does not fit in the header. rollup's npm prebuild has no header pad for it, so
  # `install` gives each dylib a short `@rpath` name, which this keeps. node loads a `.node`
  # file by its path, so the name is never read.
  preserve_rpath

  def install
    # The zip is the runnable pnpm-deploy tree (bin/, kit/, dist/, node_modules/ with
    # relative workspace symlinks, package.json). Keep the layout intact under libexec and
    # wrap the entry point.
    libexec.install Dir["*"]
    # `**` does not follow the pnpm symlinks, so each prebuild is found once, by its real path.
    libexec.glob("node_modules/.pnpm/**/*.node").each do |node|
      macho = begin
        MachO.open(node)
      rescue MachO::NotAMachOError
        next # another platform's prebuild (an ELF or PE `.node`), which node never loads here
      end
      next if !macho.dylib? || macho.dylib_id.start_with?("@")

      macho.change_dylib_id("@rpath/#{File.basename(macho.dylib_id)}")
      macho.codesign! # the edit broke the linker's ad hoc signature; sign it ad hoc again
      macho.write!
    end
    (bin/"floorplan").write <<~SH
      #!/bin/bash
      exec "#{formula_opt_bin("node")}/node" "#{libexec}/bin/floorplan.mjs" "$@"
    SH
    (bin/"floorplan").chmod 0755
  end

  def caveats
    <<~EOS
      After each install or upgrade, register its MCP servers again: they name a path in this keg.
        floorplan install
    EOS
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/floorplan --version")
    # `install` renamed and re-signed the native prebuilds; node must still load each one.
    libexec.glob("node_modules/.pnpm/**/*.node").each do |node|
      system formula_opt_bin("node")/"node", "-e", "require(process.argv[1])", node
    end
  end
end
