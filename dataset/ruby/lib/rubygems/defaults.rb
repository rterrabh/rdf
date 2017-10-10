module Gem
  DEFAULT_HOST = "https://rubygems.org"

  @post_install_hooks   ||= []
  @done_installing_hooks  ||= []
  @post_uninstall_hooks ||= []
  @pre_uninstall_hooks  ||= []
  @pre_install_hooks    ||= []


  def self.default_sources
    %w[https://rubygems.org/]
  end


  def self.default_spec_cache_dir
    File.join Gem.user_home, '.gem', 'specs'
  end


  def self.default_dir
    path = if defined? RUBY_FRAMEWORK_VERSION then
             [
               File.dirname(RbConfig::CONFIG['sitedir']),
               'Gems',
               RbConfig::CONFIG['ruby_version']
             ]
           elsif RbConfig::CONFIG['rubylibprefix'] then
             [
              RbConfig::CONFIG['rubylibprefix'],
              'gems',
              RbConfig::CONFIG['ruby_version']
             ]
           else
             [
               RbConfig::CONFIG['libdir'],
               ruby_engine,
               'gems',
               RbConfig::CONFIG['ruby_version']
             ]
           end

    @default_dir ||= File.join(*path)
  end


  def self.default_ext_dir_for base_dir
    nil
  end


  def self.default_rubygems_dirs
    nil # default to standard layout
  end


  def self.user_dir
    parts = [Gem.user_home, '.gem', ruby_engine]
    parts << RbConfig::CONFIG['ruby_version'] unless RbConfig::CONFIG['ruby_version'].empty?
    File.join parts
  end


  def self.path_separator
    File::PATH_SEPARATOR
  end


  def self.default_path
    path = []
    path << user_dir if user_home && File.exist?(user_home)
    path << default_dir
    path << vendor_dir if vendor_dir and File.directory? vendor_dir
    path
  end


  def self.default_exec_format
    exec_format = RbConfig::CONFIG['ruby_install_name'].sub('ruby', '%s') rescue '%s'

    unless exec_format =~ /%s/ then
      raise Gem::Exception,
        "[BUG] invalid exec_format #{exec_format.inspect}, no %s"
    end

    exec_format
  end


  def self.default_bindir
    if defined? RUBY_FRAMEWORK_VERSION then # mac framework support
      '/usr/bin'
    else # generic install
      RbConfig::CONFIG['bindir']
    end
  end


  def self.ruby_engine
    if defined? RUBY_ENGINE then
      RUBY_ENGINE
    else
      'ruby'
    end
  end


  def self.default_key_path
    File.join Gem.user_home, ".gem", "gem-private_key.pem"
  end


  def self.default_cert_path
    File.join Gem.user_home, ".gem", "gem-public_cert.pem"
  end

  def self.default_gems_use_full_paths?
    ruby_engine != 'ruby'
  end


  def self.install_extension_in_lib # :nodoc:
    true
  end


  def self.vendor_dir # :nodoc:
    if vendor_dir = ENV['GEM_VENDOR'] then
      return vendor_dir.dup
    end

    return nil unless RbConfig::CONFIG.key? 'vendordir'

    File.join RbConfig::CONFIG['vendordir'], 'gems',
              RbConfig::CONFIG['ruby_version']
  end

end
