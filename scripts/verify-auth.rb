# typed: strict
# frozen_string_literal: true

# Real brew entry points, with synthetic credentials only. A private entry must
# reject a missing token before any request reaches GitHub. A public entry
# (docs/specs/public-tap.md) must download with no token at all.
require "open3"
require "tmpdir"

root = Pathname.new(__dir__).parent
# VERIFY_AUTH_ENTRIES, when it names any, limits the check to those entries
# (paths from the tap root, space-separated): CI's changed entries.
entries = ENV.fetch("VERIFY_AUTH_ENTRIES", "").split
# A cask can also sit in Casks/<first character>/ (Casks/i/idavoll.rb).
paths = if entries.empty?
  root.glob("{Formula,Casks}/*.rb") + root.glob("Casks/*/*.rb")
else
  entries.map { |entry| root.join(entry) }
end
invalid_tokens = [nil, " \t\n"]
public_url = %r{\Ahttps://github\.com/21StarkCom/homebrew-tap/releases/download/[^"/]+/[^"/]+\z}
publics = 0
# Entries fall back to `gh auth token`, then a keychain token, when the env
# var is unset or blank. An empty HOME hides gh's login, so a signed-in box
# still exercises the no-token path.
Dir.mktmpdir("verify-auth-home") do |home|
  paths.each do |path|
    kind = if path.relative_path_from(root).to_s.start_with?("Casks/")
      "--cask"
    else
      "--formula"
    end
    name = "21StarkCom/tap/#{path.basename(".rb")}"
    text = path.read
    asset_url = text[/^  url "([^"]+)"/, 1]
    if asset_url&.match?(public_url)
      abort "#{name}: a public entry holds token code" if text.match?(/GitHub::API|Authorization:|CurlDownloadStrategy/)
      output, status = Open3.capture2e(
        { "HOME" => home, "HOMEBREW_GITHUB_API_TOKEN" => nil, "HOMEBREW_NO_AUTO_UPDATE" => "1" },
        HOMEBREW_BREW_FILE.to_s, "fetch", kind, name
      )
      abort "#{name}: a public entry did not download with no token:\n#{output}" unless status.success?
      # A fetch Homebrew skips exits 0 with nothing downloaded. Ask --cache as macOS
      # arm64 for a cask: it prints nothing for a macOS-only cask on Linux.
      cache_args = if kind == "--cask"
        ["--cask", "--os=tahoe", "--arch=arm"]
      else
        ["--formula"]
      end
      cache, = Open3.capture2(
        { "HOME" => home, "HOMEBREW_GITHUB_API_TOKEN" => nil, "HOMEBREW_NO_AUTO_UPDATE" => "1" },
        HOMEBREW_BREW_FILE.to_s, "--cache", *cache_args, name
      )
      abort "#{name}: a public entry's no-token fetch downloaded nothing" unless File.size?(cache.strip)
      output, status = Open3.capture2e(
        { "HOME" => home, "HOMEBREW_GITHUB_API_TOKEN" => nil, "HOMEBREW_NO_AUTO_UPDATE" => "1" },
        HOMEBREW_BREW_FILE.to_s, "info", "--json=v2", kind, name
      )
      abort "#{name}: a public entry's metadata needs a token:\n#{output}" unless status.success?
      publics += 1
      next
    end
    invalid_tokens.each do |token|
      output, status = Open3.capture2e(
        { "HOME" => home, "HOMEBREW_GITHUB_API_TOKEN" => token, "HOMEBREW_NO_AUTO_UPDATE" => "1" },
        HOMEBREW_BREW_FILE.to_s, "fetch", kind, name
      )
      abort "#{name}: fetch succeeded with no env or gh token (a keychain token?)" if status.success?
      abort "#{name}: download URL missing from error" unless output.include?("Download failed: #{asset_url}")
      abort "#{name}: token guidance missing" unless output.include?("run `gh auth login`")
    end
    output, status = Open3.capture2e(
      { "HOMEBREW_GITHUB_API_TOKEN" => "metadata-leak-sentinel", "HOMEBREW_NO_AUTO_UPDATE" => "1" },
      HOMEBREW_BREW_FILE.to_s, "info", "--json=v2", kind, name
    )
    abort "#{name}: metadata command failed" unless status.success?
    abort "#{name}: metadata exposes the token" if output.include?("metadata-leak-sentinel")
  end
end
privates = paths.length - publics
puts "#{privates} private entries: missing/blank tokens reject with URL and guidance; " \
     "JSON metadata omits credentials. #{publics} public entries: download and metadata with no token"
