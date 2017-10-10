require "erb"
require "fpm/namespace"
require "fpm/package"
require "fpm/errors"
require "fpm/util"
require "backports"
require "fileutils"
require "digest"

class FPM::Package::Sh < FPM::Package

  def output(output_path)
    create_scripts

    `cat #{install_script} #{payload} > #{output_path}`
    FileUtils.chmod("+x", output_path)
  end

  def create_scripts
    if script?(:after_install)
      File.write(File.join(fpm_meta_path, "after_install"), script(:after_install))
    end
  end

  def install_script
    path = build_path("installer.sh")
    File.open(path, "w") do |file|
      file.write template("sh.erb").result(binding)
    end
    path
  end

  def payload
    payload_tar = build_path("payload.tar")
    logger.info("Creating payload tar ", :path => payload_tar)

    args = [ tar_cmd,
             "-C",
             staging_path,
             "-cf",
             payload_tar,
             "--owner=0",
             "--group=0",
             "--numeric-owner",
             "." ]

    unless safesystem(*args)
      raise "Command failed while creating payload tar: #{args}"
    end
    payload_tar
  end

  def fpm_meta_path
    @fpm_meta_path ||= begin
                         path = File.join(staging_path, ".fpm")
                         FileUtils.mkdir_p(path)
                         path
                       end
  end
end
