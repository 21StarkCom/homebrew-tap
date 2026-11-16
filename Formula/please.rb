# frozen_string_literal: true

# please: AI & Infrastructure's CLI for PR reviews, PR walkthroughs and devops-infra plans.
# The release asset is the tagged bash and python tree (no Mach-O), built by the source repo's
# .github/workflows/release-cli.yml from tools/please/.
# Every file in bin/ goes on PATH: please, the review-pr skill and the helpers call each other by name.
class Please < Formula
  desc "Evinced AI & Infrastructure CLI for PR reviews and devops-infra plans"
  homepage "https://github.com/GetEvinced/ai-infra-agentic-resources/tree/main/tools/please"
  # version / asset id / sha256 are release-specific and rewritten when the source repo's
  # release-cli.yml calls the bumper (the README's caller table) — do not hand-edit them.
  # Homebrew's own lookup: HOMEBREW_GITHUB_API_TOKEN, else `gh auth token`, else a keychain token.
  # Its sandboxed build, test and postinstall workers reload this file where gh cannot read its
  # config. They never download (the brew process fetched first), so they skip the lookup.
  worker = %w[build.rb test.rb postinstall.rb].any? { |w| $PROGRAM_NAME == (HOMEBREW_LIBRARY_PATH/w).to_s }
  token = worker ? "" : GitHub::API.credentials.to_s.strip
  url "https://api.github.com/repos/GetEvinced/ai-infra-agentic-resources/releases/assets/754871293",
      headers: ["Accept: application/octet-stream", "Authorization: token #{token}"]
  version "0.1.0"
  sha256 "fe54fdf2d788ed8af9e7b0d07d14bc25a1e31ff880f82011e878777dea419613"
  if token.empty? && !worker
    raise CurlDownloadStrategyError.new(
      stable.url,
      "This private tap needs a GitHub token with contents:read access: " \
      "run `gh auth login` with Homebrew's gh (`brew install gh`), or set HOMEBREW_GITHUB_API_TOKEN.",
    )
  end

  depends_on arch: :arm64
  depends_on "gh"
  depends_on "jq"
  depends_on :macos

  def install
    bin.install Dir["bin/*"]
  end

  def caveats
    <<~EOS
      Run `please doctor` to check the tools, skills and sign-ins each command needs.
      `please review` also needs the review-pr skill in Claude Code:
        /plugin marketplace add GetEvinced/ai-infra-agentic-resources
        /plugin install review-pr@ai-infra-shared
    EOS
  end

  test do
    assert_equal "please #{version}", shell_output("#{bin}/please --version").strip
    %w[gh-pr-post-findings gh-pr-threads please-codex-launch please-codex-parse
       please-codex-review subagent-progress].each do |helper|
      assert_predicate bin/helper, :executable?
    end
  end
end
