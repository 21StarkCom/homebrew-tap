# typed: strict
# frozen_string_literal: true

# Real brew entry points, with synthetic credentials only. No request should
# reach GitHub when token validation fails.
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
# Entries fall back to `gh auth token`, then a keychain token, when the env
# var is unset or blank. An empty HOME hides gh's login, so a signed-in box
# still exercises the no-token path.
Dir.mktmpdir("verify-auth-home") do |home|
  paths.each do |path|
    kind = path.relative_path_from(root).to_s.start_with?("Casks/") ? "--cask" : "--formula"
    name = "21StarkCom/tap/#{path.basename(".rb")}"
    asset_url = path.read[/^  url "([^"]+)"/, 1]
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
puts "#{paths.length} entries: missing/blank tokens reject with URL and guidance; JSON metadata omits credentials"
