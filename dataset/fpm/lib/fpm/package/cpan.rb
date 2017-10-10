require "fpm/namespace"
require "fpm/package"
require "fpm/util"
require "fileutils"
require "find"

class FPM::Package::CPAN < FPM::Package
  option "--perl-bin", "PERL_EXECUTABLE",
    "The path to the perl executable you wish to run.", :default => "perl"

  option "--cpanm-bin", "CPANM_EXECUTABLE",
    "The path to the cpanm executable you wish to run.", :default => "cpanm"

  option "--mirror", "CPAN_MIRROR",
    "The CPAN mirror to use instead of the default."

  option "--mirror-only", :flag,
    "Only use the specified mirror for metadata.", :default => false

  option "--package-name-prefix", "NAME_PREFIX",
    "Name to prefix the package name with.", :default => "perl"

  option "--test", :flag,
    "Run the tests before packaging?", :default => true

  option "--perl-lib-path", "PERL_LIB_PATH",
    "Path of target Perl Libraries"

  option "--sandbox-non-core", :flag,
    "Sandbox all non-core modules, even if they're already installed", :default => true

  private
  def input(package)
    require "net/http"
    require "json"

    if (attributes[:cpan_local_module?])
      moduledir = package
    else
      result = search(package)
      tarball = download(result, version)
      moduledir = unpack(tarball)
    end

    if File.exist?(File.join(moduledir, "META.json"))
      metadata = JSON.parse(File.read(File.join(moduledir, ("META.json"))))
    elsif File.exist?(File.join(moduledir, ("META.yml")))
      require "yaml"
      metadata = YAML.load_file(File.join(moduledir, ("META.yml")))
    elsif File.exist?(File.join(moduledir, "MYMETA.json"))
      metadata = JSON.parse(File.read(File.join(moduledir, ("MYMETA.json"))))
    elsif File.exist?(File.join(moduledir, ("MYMETA.yml")))
      require "yaml"
      metadata = YAML.load_file(File.join(moduledir, ("MYMETA.yml")))
    else
      raise FPM::InvalidPackageConfiguration,
        "Could not find package metadata. Checked for META.json and META.yml"
    end
    self.version = metadata["version"]
    self.description = metadata["abstract"]

    self.license = case metadata["license"]
      when Array; metadata["license"].first
      when nil; "unknown"
      else; metadata["license"]
    end

    unless metadata["distribution"].nil?
      logger.info("Setting package name from 'distribution'",
                   :distribution => metadata["distribution"])
      self.name = fix_name(metadata["distribution"])
    else
      logger.info("Setting package name from 'name'",
                   :name => metadata["name"])
      self.name = fix_name(metadata["name"])
    end

    self.vendor = case metadata["author"]
      when String; metadata["author"]
      when Array; metadata["author"].join(", ")
      else
        raise FPM::InvalidPackageConfiguration, "Unexpected CPAN 'author' field type: #{metadata["author"].class}. This is a bug."
    end if metadata.include?("author")

    self.url = metadata["resources"]["homepage"] rescue "unknown"

    self.architecture = "all"

    logger.info("Installing any build or configure dependencies")

    if attributes[:cpan_sandbox_non_core?]
      cpanm_flags = ["-L", build_path("cpan"), moduledir]
    else
      cpanm_flags = ["-l", build_path("cpan"), moduledir]
    end

    cpanm_flags += ["--installdeps"]
    cpanm_flags += ["-n"] if !attributes[:cpan_test?]
    cpanm_flags += ["--mirror", "#{attributes[:cpan_mirror]}"] if !attributes[:cpan_mirror].nil?
    cpanm_flags += ["--mirror-only"] if attributes[:cpan_mirror_only?] && !attributes[:cpan_mirror].nil?

    safesystem(attributes[:cpan_cpanm_bin], *cpanm_flags)

    if !attributes[:no_auto_depends?]
      unless metadata["requires"].nil?
        metadata["requires"].each do |dep_name, version|
          if dep_name == "perl"
            self.dependencies << "#{dep_name} >= #{version}"
            next
          end
          dep = search(dep_name)

          if dep.include?("distribution")
            name = fix_name(dep["distribution"])
          else
            name = fix_name(dep_name)
          end

          if version.to_s == "0"
            self.dependencies << "#{name}"
          else
            if version.is_a?(String)
              version.split(/\s*,\s*/).each do |v|
                if v =~ /\s*[><=]/
                  self.dependencies << "#{name} #{v}"
                else
                  self.dependencies << "#{name} = #{v}"
                end
              end
            else
              self.dependencies << "#{name} >= #{version}"
            end
          end
        end
      end
    end #no_auto_depends

    ::Dir.chdir(moduledir) do

      prefix = attributes[:prefix] || "/usr/local"

      if File.exist?("Build.PL")
        safesystem(attributes[:cpan_perl_bin],
                   "-Mlocal::lib=#{build_path("cpan")}",
                   "Build.PL")
        safesystem(attributes[:cpan_perl_bin],
                   "-Mlocal::lib=#{build_path("cpan")}",
                   "./Build")

        if attributes[:cpan_test?]
          safesystem(attributes[:cpan_perl_bin],
                   "-Mlocal::lib=#{build_path("cpan")}",
                   "./Build", "test")
        end
        if attributes[:cpan_perl_lib_path]
          perl_lib_path = attributes[:cpan_perl_lib_path]
          safesystem("./Build install --install_path lib=#{perl_lib_path} \
                     --destdir #{staging_path} --prefix #{prefix} --destdir #{staging_path}")
        else
           safesystem("./Build", "install",
                     "--prefix", prefix, "--destdir", staging_path,
                     "--install_base", "")
        end
      elsif File.exist?("Makefile.PL")
        if attributes[:cpan_perl_lib_path]
          perl_lib_path = attributes[:cpan_perl_lib_path]
          safesystem(attributes[:cpan_perl_bin],
                     "-Mlocal::lib=#{build_path("cpan")}",
                     "Makefile.PL", "PREFIX=#{prefix}", "LIB=#{perl_lib_path}",
                     "INSTALL_BASE=")
        else
          safesystem(attributes[:cpan_perl_bin],
                     "-Mlocal::lib=#{build_path("cpan")}",
                     "Makefile.PL", "PREFIX=#{prefix}",
                     "INSTALL_BASE=")
        end
        if attributes[:cpan_test?]
          make = [ "env", "PERL5LIB=#{build_path("cpan/lib/perl5")}", "make" ]
        else
          make = [ "make" ]
        end
        safesystem(*make)
        safesystem(*(make + ["test"])) if attributes[:cpan_test?]
        safesystem(*(make + ["DESTDIR=#{staging_path}", "install"]))


      else
        raise FPM::InvalidPackageConfiguration,
          "I don't know how to build #{name}. No Makefile.PL nor " \
          "Build.PL found"
      end

      glob_prefix = attributes[:cpan_perl_lib_path] || prefix
      ::Dir.glob(File.join(staging_path, glob_prefix, "**/perllocal.pod")).each do |path|
        logger.debug("Removing useless file.",
                      :path => path.gsub(staging_path, ""))
        File.unlink(path)
      end
    end


    self.architecture = "all"

    Find.find(staging_path) do |path|
      if path =~ /\.so$/
        logger.info("Found shared library, setting architecture=native",
                     :path => path)
        self.architecture = "native"
      end
    end
  end

  def unpack(tarball)
    directory = build_path("module")
    ::Dir.mkdir(directory)
    args = [ "-C", directory, "-zxf", tarball,
      "--strip-components", "1" ]
    safesystem("tar", *args)
    return directory
  end

  def download(metadata, cpan_version=nil)
    distribution = metadata["distribution"]
    author = metadata["author"]

    logger.info("Downloading perl module",
                 :distribution => distribution,
                 :version => cpan_version)

    if cpan_version.nil?
      self.version = metadata["version"]
    else
      if metadata["version"] =~ /^v\d/
        self.version = "v#{cpan_version}"
      else
        self.version = cpan_version
      end
    end

    metacpan_release_url = "http://api.metacpan.org/v0/release/#{author}/#{distribution}-#{self.version}"
    begin
      release_response = httpfetch(metacpan_release_url)
    rescue Net::HTTPServerException => e
      logger.error("metacpan release query failed.", :error => e.message,
                    :module => package, :url => metacpan_release_url)
      raise FPM::InvalidPackageConfiguration, "metacpan release query failed"
    end

    data = release_response.body
    release_metadata = JSON.parse(data)
    archive = release_metadata["archive"]

    tarball = File.basename(archive)

    url_base = "http://www.cpan.org/"
    url_base = "#{attributes[:cpan_mirror]}" if !attributes[:cpan_mirror].nil?

    url = "#{url_base}/authors/id/#{author[0,1]}/#{author[0,2]}/#{author}/#{archive}"
    logger.debug("Fetching perl module", :url => url)

    begin
      response = httpfetch(url)
    rescue Net::HTTPServerException => e
      logger.error("Download failed", :error => e, :url => url)
      raise FPM::InvalidPackageConfiguration, "metacpan query failed"
    end

    File.open(build_path(tarball), "w") do |fd|
      fd.write(response.body)
    end
    return build_path(tarball)
  end # def download

  def search(package)
    logger.info("Asking metacpan about a module", :module => package)
    metacpan_url = "http://api.metacpan.org/v0/module/" + package
    begin
      response = httpfetch(metacpan_url)
    rescue Net::HTTPServerException => e
      logger.error("metacpan query failed.", :error => e.message,
                    :module => package, :url => metacpan_url)
      raise FPM::InvalidPackageConfiguration, "metacpan query failed"
    end

    data = response.body
    metadata = JSON.parse(data)
    return metadata
  end # def metadata

  def fix_name(name)
    case name
      when "perl"; return "perl"
      else; return [attributes[:cpan_package_name_prefix], name].join("-").gsub("::", "-")
    end
  end # def fix_name

  def httpfetch(url)
    uri = URI.parse(url)
    if ENV['http_proxy']
      proxy = URI.parse(ENV['http_proxy'])
      http = Net::HTTP.Proxy(proxy.host,proxy.port,proxy.user,proxy.password).new(uri.host, uri.port)
    else
      http = Net::HTTP.new(uri.host, uri.port)
    end
    response = http.request(Net::HTTP::Get.new(uri.request_uri))
    case response
      when Net::HTTPSuccess; return response
      when Net::HTTPRedirection; return httpfetch(response["location"])
      else; response.error!
    end
  end

  public(:input)
end # class FPM::Package::NPM
