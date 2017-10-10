require "backports" # gem backports
require "fpm/package"
require "fpm/util"
require "fileutils"
require "fpm/package/dir"

class FPM::Package::Zip < FPM::Package

  def input(input_path)
    self.name = File.extname(input_path)[1..-1]

    realpath = Pathname.new(input_path).realpath.to_s
    ::Dir.chdir(build_path) do
      safesystem("unzip", realpath)
    end

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

    files = Find.find(staging_path).to_a
    safesystem("zip", output_path, *files)
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
