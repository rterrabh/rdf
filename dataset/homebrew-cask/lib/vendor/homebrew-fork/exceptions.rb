module Hbc; end

class Hbc::ErrorDuringExecution < RuntimeError
  def initialize(cmd, args=[])
    args = args.map { |a| a.to_s.gsub " ", "\\ " }.join(" ")
    super "Failure while executing: #{cmd} #{args}"
  end
end

class Hbc::CurlDownloadStrategyError < RuntimeError; end
