require 'fileutils'
require "pathname"

require 'vagrant/util/safe_chdir'
require 'vagrant/util/subprocess'

module Vagrant
  module Action
    module General
      class Package
        include Util

        def initialize(app, env)
          @app = app

          env["package.files"]  ||= {}
          env["package.output"] ||= "package.box"
        end

        def call(env)
          @env = env
          file_name = File.basename(@env["package.output"].to_s)
          
          raise Errors::PackageOutputDirectory if File.directory?(tar_path)
          raise Errors::PackageOutputExists, file_name:file_name if File.exist?(tar_path)
          raise Errors::PackageRequiresDirectory if !env["package.directory"] ||
            !File.directory?(env["package.directory"])

          @app.call(env)

          @env[:ui].info I18n.t("vagrant.actions.general.package.compressing", tar_path: tar_path)
          copy_include_files
          setup_private_key
          compress
        end

        def recover(env)
          @env = env

          ignore_exc = [Errors::PackageOutputDirectory, Errors::PackageOutputExists]
          ignore_exc.each do |exc|
            return if env["vagrant.error"].is_a?(exc)
          end

          File.delete(tar_path) if File.exist?(tar_path)
        end

        def copy_include_files
          include_directory = Pathname.new(@env["package.directory"]).join("include")

          @env["package.files"].each do |from, dest|
            to = include_directory.join(dest)

            @env[:ui].info I18n.t("vagrant.actions.general.package.packaging", file: from)
            FileUtils.mkdir_p(to.parent)

            if File.directory?(from)
              FileUtils.cp_r(Dir.glob(from), to.parent, preserve: true)
            else
              FileUtils.cp(from, to, preserve: true)
            end
          end
        rescue Errno::EEXIST => e
          raise if !e.to_s.include?("symlink")

          raise Errors::PackageIncludeSymlink
        end

        def compress
          output_path = tar_path.to_s

          Util::SafeChdir.safe_chdir(@env["package.directory"]) do
            files = Dir.glob(File.join(".", "*"))

            Util::Subprocess.execute("bsdtar", "-czf", output_path, *files)
          end
        end

        def setup_private_key
          return if !@env[:machine]

          return if !@env[:machine].data_dir

          path = @env[:machine].data_dir.join("private_key")
          return if !path.file?

          dir = Pathname.new(@env["package.directory"])
          new_path = dir.join("vagrant_private_key")
          FileUtils.cp(path, new_path)

          vf_path = dir.join("Vagrantfile")
          mode = "w+"
          mode = "a" if vf_path.file?
          vf_path.open(mode) do |f|
            f.binmode
            f.puts
            f.puts %Q[Vagrant.configure("2") do |config|]
            f.puts %Q[  config.ssh.private_key_path = File.expand_path("../vagrant_private_key", __FILE__)]
            f.puts %Q[end]
          end
        end

        def tar_path
          File.expand_path(@env["package.output"], FileUtils.pwd)
        end
      end
    end
  end
end
