
require 'rake'
require 'rake/tasklib'

module Rake

  class PackageTask < TaskLib
    attr_accessor :name

    attr_accessor :version

    attr_accessor :package_dir

    attr_accessor :need_tar

    attr_accessor :need_tar_gz

    attr_accessor :need_tar_bz2

    attr_accessor :need_zip

    attr_accessor :package_files

    attr_accessor :tar_command

    attr_accessor :zip_command


    def initialize(name=nil, version=nil)
      init(name, version)
      yield self if block_given?
      define unless name.nil?
    end

    def init(name, version)
      @name = name
      @version = version
      @package_files = Rake::FileList.new
      @package_dir = 'pkg'
      @need_tar = false
      @need_tar_gz = false
      @need_tar_bz2 = false
      @need_zip = false
      @tar_command = 'tar'
      @zip_command = 'zip'
    end

    def define
      fail "Version required (or :noversion)" if @version.nil?
      @version = nil if :noversion == @version

      desc "Build all the packages"
      task :package

      desc "Force a rebuild of the package files"
      task :repackage => [:clobber_package, :package]

      desc "Remove package products"
      task :clobber_package do
        rm_r package_dir rescue nil
      end

      task :clobber => [:clobber_package]

      [
        [need_tar, tgz_file, "z"],
        [need_tar_gz, tar_gz_file, "z"],
        [need_tar_bz2, tar_bz2_file, "j"]
      ].each do |(need, file, flag)|
        if need
          task :package => ["#{package_dir}/#{file}"]
          file "#{package_dir}/#{file}" =>
            [package_dir_path] + package_files do
            chdir(package_dir) do
              sh @tar_command, "#{flag}cvf", file, package_name
            end
          end
        end
      end

      if need_zip
        task :package => ["#{package_dir}/#{zip_file}"]
        file "#{package_dir}/#{zip_file}" =>
          [package_dir_path] + package_files do
          chdir(package_dir) do
            sh @zip_command, "-r", zip_file, package_name
          end
        end
      end

      directory package_dir_path => @package_files do
        @package_files.each do |fn|
          f = File.join(package_dir_path, fn)
          fdir = File.dirname(f)
          mkdir_p(fdir) unless File.exist?(fdir)
          if File.directory?(fn)
            mkdir_p(f)
          else
            rm_f f
            safe_ln(fn, f)
          end
        end
      end
      self
    end


    def package_name
      @version ? "#{@name}-#{@version}" : @name
    end


    def package_dir_path
      "#{package_dir}/#{package_name}"
    end


    def tgz_file
      "#{package_name}.tgz"
    end


    def tar_gz_file
      "#{package_name}.tar.gz"
    end


    def tar_bz2_file
      "#{package_name}.tar.bz2"
    end


    def zip_file
      "#{package_name}.zip"
    end
  end

end
