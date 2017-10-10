module Jekyll
  module Utils
    module Platforms extend self


      { :jruby? => "jruby", :mri? => "ruby" }.each do |k, v|
        #nodyna <define_method-2953> <not yet classified>
        define_method k do
          ::RUBY_ENGINE == v
        end
      end


      { :windows? => /mswin|mingw|cygwin/, :linux? => /linux/, \
          :osx? => /darwin|mac os/, :unix? => /solaris|bsd/ }.each do |k, v|

        #nodyna <define_method-2954> <not yet classified>
        define_method k do
          !!(
            RbConfig::CONFIG["host_os"] =~ v
          )
        end
      end
    end
  end
end
