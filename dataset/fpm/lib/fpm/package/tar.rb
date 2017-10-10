require "backports" # gem backports
require "fpm/package"
require "fpm/util"
require "fileutils"
require "fpm/package/dir"

class FPM::Package::Tar < FPM::Package

  def input(input_path)
    self.name = File.basename(input_path).split(".").first

    args = ["-xf", input_path, "-C", build_path]

    with(tar_compression_flag(input_path)) do |flag|
      args << flag unless flag.nil?
    end

    safesystem("tar", *args)

    dir = convert(FPM::Package::Dir)
    if attributes[:chdir]
      dir.attributes[:chdir] = File.join(build_path, attributes[:chdir])
    else
      dir.attributes[:chdir] = build_path
    end

    cleanup_staging
    dir.input(".")
    @staging_path = dir.staging_path
    dir.cleanup_build
  end # def input

  def output(output_path)
    output_check(output_path)
    args = ["-cf", output_path, "-C", staging_path]
    with(tar_compression_flag(output_path)) do |flag|
      args << flag unless flag.nil?
    end
    args << "."

    safesystem("tar", *args)
  end # def output

  def tar_compression_flag(path)
    case path
      when /\.tar\.bz2$/
        return "-j"
      when /\.tar\.gz$|\.tgz$/
        return "-z"
      when /\.tar\.xz$/
        return "-J"
      else
        return nil
    end
  end # def tar_compression_flag
end # class FPM::Package::Tar
