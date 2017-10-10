
require 'uri'
require 'rubygems'


module Gem::LocalRemoteOptions


  def accept_uri_http
    OptionParser.accept URI::HTTP do |value|
      begin
        uri = URI.parse value
      rescue URI::InvalidURIError
        raise OptionParser::InvalidArgument, value
      end

      unless ['http', 'https', 'file'].include?(uri.scheme)
         raise OptionParser::InvalidArgument, value
      end

      value
    end
  end


  def add_local_remote_options
    add_option(:"Local/Remote", '-l', '--local',
               'Restrict operations to the LOCAL domain') do |value, options|
      options[:domain] = :local
    end

    add_option(:"Local/Remote", '-r', '--remote',
      'Restrict operations to the REMOTE domain') do |value, options|
      options[:domain] = :remote
    end

    add_option(:"Local/Remote", '-b', '--both',
               'Allow LOCAL and REMOTE operations') do |value, options|
      options[:domain] = :both
    end

    add_bulk_threshold_option
    add_clear_sources_option
    add_source_option
    add_proxy_option
    add_update_sources_option
  end


  def add_bulk_threshold_option
    add_option(:"Local/Remote", '-B', '--bulk-threshold COUNT',
               "Threshold for switching to bulk",
               "synchronization (default #{Gem.configuration.bulk_threshold})") do
      |value, options|
      Gem.configuration.bulk_threshold = value.to_i
    end
  end


  def add_clear_sources_option
    add_option(:"Local/Remote", '--clear-sources',
               'Clear the gem sources') do |value, options|

      Gem.sources = nil
      options[:sources_cleared] = true
    end
  end


  def add_proxy_option
    accept_uri_http

    add_option(:"Local/Remote", '-p', '--[no-]http-proxy [URL]', URI::HTTP,
               'Use HTTP proxy for remote operations') do |value, options|
      options[:http_proxy] = (value == false) ? :no_proxy : value
      Gem.configuration[:http_proxy] = options[:http_proxy]
    end
  end


  def add_source_option
    accept_uri_http

    add_option(:"Local/Remote", '-s', '--source URL', URI::HTTP,
               'Append URL to list of remote gem sources') do |source, options|

      source << '/' if source !~ /\/\z/

      if options.delete :sources_cleared then
        Gem.sources = [source]
      else
        Gem.sources << source unless Gem.sources.include?(source)
      end
    end
  end


  def add_update_sources_option
    add_option(:Deprecated, '-u', '--[no-]update-sources',
               'Update local source cache') do |value, options|
      Gem.configuration.update_sources = value
    end
  end


  def both?
    options[:domain] == :both
  end


  def local?
    options[:domain] == :local || options[:domain] == :both
  end


  def remote?
    options[:domain] == :remote || options[:domain] == :both
  end

end

