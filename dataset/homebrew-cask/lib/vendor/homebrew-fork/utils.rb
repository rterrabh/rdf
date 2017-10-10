require 'pathname'
require 'vendor/homebrew-fork/exceptions'

def homebrew_fork_system cmd, *args
  puts "#{cmd} #{args*' '}" if Hbc.verbose
  pid = fork do
    yield if block_given?
    args.collect!{|arg| arg.to_s}
    exec(cmd, *args) rescue nil
    exit! 1 # never gets here unless exec failed
  end
  Process.wait(pid)
  $?.success?
end

def safe_system cmd, *args
  homebrew_fork_system(cmd, *args) or raise Hbc::ErrorDuringExecution.new(cmd, args)
end

def quiet_system cmd, *args
  homebrew_fork_system(cmd, *args) do
    $stdout.reopen('/dev/null')
    $stderr.reopen('/dev/null')
  end
end

def curl *args
  curl = Pathname.new '/usr/bin/curl'
  raise "#{curl} is not executable" unless curl.exist? and curl.executable?

  flags = HOMEBREW_CURL_ARGS
  flags = flags.delete("#") if Hbc.verbose

  args = [flags, HOMEBREW_USER_AGENT, *args]
  args << "--insecure" if MacOS.release < "10.6"
  args << "--verbose" if ENV['HOMEBREW_CURL_VERBOSE']
  args << "--silent" unless $stdout.tty?

  safe_system curl, *args
end
