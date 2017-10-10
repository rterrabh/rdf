require "bundler"

module Vagrant
  module Util
    class Env
      def self.with_original_env
        original_env = ENV.to_hash
        ENV.replace(::Bundler::ORIGINAL_ENV) if defined?(::Bundler::ORIGINAL_ENV)
        ENV.update(Vagrant.original_env)
        yield
      ensure
        ENV.replace(original_env.to_hash)
      end

      def self.with_clean_env
        with_original_env do
          ENV["MANPATH"] = ENV["BUNDLE_ORIG_MANPATH"]
          ENV.delete_if { |k,_| k[0,7] == "BUNDLE_" }
          if ENV.has_key? "RUBYOPT"
            ENV["RUBYOPT"] = ENV["RUBYOPT"].sub("-rbundler/setup", "")
            ENV["RUBYOPT"] = ENV["RUBYOPT"].sub("-I#{File.expand_path('..', __FILE__)}", "")
          end
          yield
        end
      end
    end
  end
end
