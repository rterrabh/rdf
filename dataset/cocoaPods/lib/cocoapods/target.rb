module Pod
  class Target
    attr_reader :sandbox

    attr_accessor :host_requires_frameworks
    alias_method :host_requires_frameworks?, :host_requires_frameworks

    def initialize
      @archs = []
    end

    def name
      label
    end

    def product_name
      if requires_frameworks?
        framework_name
      else
        static_library_name
      end
    end

    def product_basename
      if requires_frameworks?
        product_module_name
      else
        label
      end
    end

    def framework_name
      "#{product_module_name}.framework"
    end

    def static_library_name
      "lib#{label}.a"
    end

    def product_type
      requires_frameworks? ? :framework : :static_library
    end

    def inspect
      "<#{self.class} name=#{name} >"
    end


    def requires_frameworks?
      host_requires_frameworks? || false
    end



    attr_accessor :user_build_configurations

    attr_accessor :native_target

    attr_accessor :archs



    def support_files_dir
      sandbox.target_support_files_dir(name)
    end

    def xcconfig_path(variant = nil)
      if variant
        support_files_dir + "#{label}.#{variant.gsub(File::SEPARATOR, '-').downcase}.xcconfig"
      else
        support_files_dir + "#{label}.xcconfig"
      end
    end

    def umbrella_header_path
      support_files_dir + "#{label}-umbrella.h"
    end

    def module_map_path
      support_files_dir + "#{label}.modulemap"
    end

    def prefix_header_path
      support_files_dir + "#{label}-prefix.pch"
    end

    def bridge_support_path
      support_files_dir + "#{label}.bridgesupport"
    end

    def info_plist_path
      support_files_dir + 'Info.plist'
    end

    def dummy_source_path
      support_files_dir + "#{label}-dummy.m"
    end


    private

    def c99ext_identifier(name)
      name.gsub(/^([0-9])/, '_\1').gsub(/[^a-zA-Z0-9_]/, '_')
    end
  end
end
