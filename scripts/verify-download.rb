# frozen_string_literal: true

# Run with brew ruby in an isolated HOMEBREW_CACHE and a read-only release token.
# Never enable curl verbose/debug output: only report non-secret evidence.
require "formulary"
require "digest"

formula = Formulary.factory("21StarkCom/tap/hermod")
downloader = formula.downloader
abort "Expected Homebrew's native CurlDownloadStrategy" unless downloader.instance_of?(CurlDownloadStrategy)

modified, size = downloader.resolved_time_file_size
abort "Authenticated preflight did not return release metadata" if modified.nil? || !size.positive?
puts "Authenticated preflight: Content-Length=#{size}, Last-Modified=#{modified.utc.iso8601}"

downloader.fetch
cached = downloader.cached_location
abort "Release checksum mismatch" if Digest::SHA256.file(cached).hexdigest != formula.stable.checksum.hexdigest
puts "Full fetch: SHA-256 matches the formula"

# Seed a partial in this dedicated cache, then observe that the native curl path
# requests resume. No headers or URLs containing signed query strings are logged.
partial = downloader.temporary_path
partial.binwrite(cached.binread(size / 2))
cached.unlink
downloader = CurlDownloadStrategy.new(formula.stable.url, formula.name, formula.version, **formula.stable.specs)
resumed = false
downloader.define_singleton_method(:curl) do |*args, **options|
  resumed ||= args.include?("--continue-at")
  super(*args, **options)
end
downloader.fetch
abort "Native downloader did not request resume" unless resumed
abort "Resumed checksum mismatch" if Digest::SHA256.file(cached).hexdigest != formula.stable.checksum.hexdigest
puts "Partial fetch: curl --continue-at requested; SHA-256 matches the formula"
