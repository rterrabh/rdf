
require 'rake'


module Rake
  module Cleaner
    extend FileUtils

    module_function

    def cleanup_files(file_names)
      file_names.each do |file_name|
        cleanup(file_name)
      end
    end

    def cleanup(file_name, opts={})
      begin
        rm_r file_name, opts
      rescue StandardError => ex
        puts "Failed to remove #{file_name}: #{ex}" unless file_already_gone?(file_name)
      end
    end

    def file_already_gone?(file_name)
      return false if File.exist?(file_name)

      path = file_name
      prev = nil

      while path = File.dirname(path)
        return false if cant_be_deleted?(path)
        break if [prev, "."].include?(path)
        prev = path
      end
      true
    end
    private_class_method :file_already_gone?

    def cant_be_deleted?(path_name)
      File.exist?(path_name) &&
        (!File.readable?(path_name) || !File.executable?(path_name))
    end
    private_class_method :cant_be_deleted?
  end
end

CLEAN = ::Rake::FileList["**/*~", "**/*.bak", "**/core"]
CLEAN.clear_exclude.exclude { |fn|
  fn.pathmap("%f").downcase == 'core' && File.directory?(fn)
}

desc "Remove any temporary products."
task :clean do
  Rake::Cleaner.cleanup_files(CLEAN)
end

CLOBBER = ::Rake::FileList.new

desc "Remove any generated file."
task :clobber => [:clean] do
  Rake::Cleaner.cleanup_files(CLOBBER)
end
