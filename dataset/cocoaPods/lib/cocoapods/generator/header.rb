module Pod
  module Generator
    class Header
      attr_reader :platform

      attr_accessor :imports

      attr_accessor :module_imports

      def initialize(platform)
        @platform = platform
        @imports = []
        @module_imports = []
      end

      def generate
        result = ''
        result << generate_platform_import_header

        result << "\n"

        imports.each do |import|
          result << %(#import "#{import}"\n)
        end

        unless module_imports.empty?
          module_imports.each do |import|
            result << %(\n@import #{import})
          end
          result << "\n"
        end

        result
      end

      def save_as(path)
        path.open('w') { |header| header.write(generate) }
      end


      protected

      def generate_platform_import_header
        case platform.name
        when :ios then "#import <UIKit/UIKit.h>\n"
        when :osx then "#import <Cocoa/Cocoa.h>\n"
        else "#import <Foundation/Foundation.h>\n"
        end
      end
    end
  end
end
