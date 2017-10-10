
require 'vendor/homebrew-fork/monkeypatch_pathname'
require 'vendor/homebrew-fork/utils'
require 'tmpdir'

TEST_TMPDIR = Dir.mktmpdir("homebrew_tests")
at_exit { FileUtils.remove_entry(TEST_TMPDIR) }

HOMEBREW_CACHE         = Pathname.new(TEST_TMPDIR).join('cache')
HOMEBREW_USER_AGENT    = 'Homebrew'
HOMEBREW_CURL_ARGS     = '-fsLA'
