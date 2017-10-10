
if RUBY_VERSION.to_i < 2
  raise 'brew-cask: Ruby 2.0 or greater is required.'
end

require 'pathname'

$LOAD_PATH.unshift(File.expand_path('..', Pathname.new(__FILE__).realpath))

require 'vendor/homebrew-fork/global'

require 'hbc'

Hbc::CLI.process(ARGV)
exit 0
