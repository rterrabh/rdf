
module Gem
  GEM_PRELUDE_SUCKAGE = RUBY_VERSION =~ /^1\.9\.2/ and RUBY_ENGINE == "ruby"
end

if Gem::GEM_PRELUDE_SUCKAGE and defined?(Gem::QuickLoader) then
  Gem::QuickLoader.remove

  $LOADED_FEATURES.delete Gem::QuickLoader.path_to_full_rubygems_library

  if path = $LOADED_FEATURES.find {|n| n.end_with? '/rubygems.rb'} then
    raise LoadError, "another rubygems is already loaded from #{path}"
  end

  class << Gem
    remove_method :try_activate if Gem.respond_to?(:try_activate, true)
  end
end

module Gem
  RubyGemsVersion = VERSION


  RbConfigPriorities = %w[
    MAJOR
    MINOR
    TEENY
    EXEEXT RUBY_SO_NAME arch bindir datadir libdir ruby_install_name
    ruby_version rubylibprefix sitedir sitelibdir vendordir vendorlibdir
    rubylibdir
  ]

  unless defined?(ConfigMap)
    ConfigMap = Hash.new do |cm, key| # TODO remove at RubyGems 3
      cm[key] = RbConfig::CONFIG[key.to_s]
    end
  else
    RbConfigPriorities.each do |key|
      ConfigMap[key.to_sym] = RbConfig::CONFIG[key]
    end
  end

  RubyGemsPackageVersion = VERSION
end
