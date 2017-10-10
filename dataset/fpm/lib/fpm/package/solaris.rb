require "erb"
require "fpm/namespace"
require "fpm/package"
require "fpm/errors"
require "fpm/util"

class FPM::Package::Solaris < FPM::Package

  option "--user", "USER",
    "Set the user to USER in the prototype files.",
    :default => 'root'

  option "--group", "GROUP",
    "Set the group to GROUP in the prototype file.",
    :default => 'root'

  def architecture
    case @architecture
    when nil, "native"
      @architecture = %x{uname -p}.chomp
    end

    return @architecture
  end # def architecture

  def specfile(builddir)
    "#{builddir}/pkginfo"
  end

  def output(output_path)
    self.scripts.each do |name, path|
      case name
        when "pre-install"
          safesystem("cp", path, "./preinstall")
          File.chmod(0755, "./preinstall")
        when "post-install"
          safesystem("cp", path, "./postinstall")
          File.chmod(0755, "./postinstall")
        when "pre-uninstall"
          raise FPM::InvalidPackageConfiguration.new(
            "pre-uninstall is not supported by Solaris packages"
          )
        when "post-uninstall"
          raise FPM::InvalidPackageConfiguration.new(
            "post-uninstall is not supported by Solaris packages"
          )
      end # case name
    end # self.scripts.each

    template = template("solaris.erb")
    File.open("#{build_path}/pkginfo", "w") do |pkginfo|
      pkginfo.puts template.result(binding)
    end

    File.open("#{build_path}/Prototype", "w") do |prototype|
      prototype.puts("i pkginfo")
      prototype.puts("i preinstall") if self.scripts["pre-install"]
      prototype.puts("i postinstall") if self.scripts["post-install"]

      IO.popen("pkgproto #{staging_path}/#{@prefix}=").each_line do |line|
        type, klass, path, mode, user, group = line.split

        prototype.puts([type, klass, path, mode, attributes[:solaris_user], attributes[:solaris_group]].join(" "))
      end # popen "pkgproto ..."
    end # File prototype

    ::Dir.chdir staging_path do
      safesystem("pkgmk", "-o", "-f", "#{build_path}/Prototype", "-d", build_path)
    end


    safesystem("pkgtrans", "-s", build_path, output_path, name)
    safesystem("cp", "#{build_path}/#{output_path}", output_path)
  end # def output

  def default_output
    v = version
    v = "#{epoch}:#{v}" if epoch
    if iteration
      "#{name}_#{v}-#{iteration}_#{architecture}.#{type}"
    else
      "#{name}_#{v}_#{architecture}.#{type}"
    end
  end # def default_output
end # class FPM::Deb

