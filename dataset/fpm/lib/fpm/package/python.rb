require "fpm/namespace"
require "fpm/package"
require "fpm/util"
require "rubygems/package"
require "rubygems"
require "fileutils"
require "tmpdir"
require "json"

class FPM::Package::Python < FPM::Package
  option "--bin", "PYTHON_EXECUTABLE",
    "The path to the python executable you wish to run.", :default => "python"
  option "--easyinstall", "EASYINSTALL_EXECUTABLE",
    "The path to the easy_install executable tool", :default => "easy_install"
  option "--pip", "PIP_EXECUTABLE",
    "The path to the pip executable tool. If not specified, easy_install " \
    "is used instead", :default => nil
  option "--pypi", "PYPI_URL",
    "PyPi Server uri for retrieving packages.",
    :default => "https://pypi.python.org/simple"
  option "--package-prefix", "NAMEPREFIX",
    "(DEPRECATED, use --package-name-prefix) Name to prefix the package " \
    "name with." do |value|
    logger.warn("Using deprecated flag: --package-prefix. Please use " \
                 "--package-name-prefix")
    value
  end
  option "--package-name-prefix", "PREFIX", "Name to prefix the package " \
    "name with.", :default => "python"
  option "--fix-name", :flag, "Should the target package name be prefixed?",
    :default => true
  option "--fix-dependencies", :flag, "Should the package dependencies be " \
    "prefixed?", :default => true

  option "--downcase-name", :flag, "Should the target package name be in " \
    "lowercase?", :default => true
  option "--downcase-dependencies", :flag, "Should the package dependencies " \
    "be in lowercase?", :default => true

  option "--install-bin", "BIN_PATH", "The path to where python scripts " \
    "should be installed to."
  option "--install-lib", "LIB_PATH", "The path to where python libs " \
    "should be installed to (default depends on your python installation). " \
    "Want to find out what your target platform is using? Run this: " \
    "python -c 'from distutils.sysconfig import get_python_lib; " \
    "print get_python_lib()'"
  option "--install-data", "DATA_PATH", "The path to where data should be " \
    "installed to. This is equivalent to 'python setup.py --install-data " \
    "DATA_PATH"
  option "--dependencies", :flag, "Include requirements defined in setup.py" \
    " as dependencies.", :default => true
  option "--obey-requirements-txt", :flag, "Use a requirements.txt file " \
    "in the top-level directory of the python package for dependency " \
    "detection.", :default => false
  option "--scripts-executable", "PYTHON_EXECUTABLE", "Set custom python " \
    "interpreter in installing scripts. By default distutils will replace " \
    "python interpreter in installing scripts (specified by shebang) with " \
    "current python interpreter (sys.executable). This option is equivalent " \
    "to appending 'build_scripts --executable PYTHON_EXECUTABLE' arguments " \
    "to 'setup.py install' command."
  option "--disable-dependency", "python_package_name",
    "The python package name to remove from dependency list",
    :multivalued => true, :attribute_name => :python_disable_dependency,
    :default => []

  private

  def input(package)
    path_to_package = download_if_necessary(package, version)

    if File.directory?(path_to_package)
      setup_py = File.join(path_to_package, "setup.py")
    else
      setup_py = path_to_package
    end

    if !File.exist?(setup_py)
      logger.error("Could not find 'setup.py'", :path => setup_py)
      raise "Unable to find python package; tried #{setup_py}"
    end

    load_package_info(setup_py)
    install_to_staging(setup_py)
  end # def input

  def download_if_necessary(package, version=nil)
    path = package
    if File.directory?(path) or (File.exist?(path) and File.basename(path) == "setup.py")
      return path
    end

    logger.info("Trying to download", :package => package)

    if version.nil?
      want_pkg = "#{package}"
    else
      want_pkg = "#{package}==#{version}"
    end

    target = build_path(package)
    FileUtils.mkdir(target) unless File.directory?(target)

    if attributes[:python_pip].nil?
      logger.debug("no pip, defaulting to easy_install", :easy_install => attributes[:python_easyinstall])
      safesystem(attributes[:python_easyinstall], "-i",
                 attributes[:python_pypi], "--editable", "-U",
                 "--build-directory", target, want_pkg)
    else
      logger.debug("using pip", :pip => attributes[:python_pip])
      safesystem(attributes[:python_pip], "install", "--no-deps", "--no-install", "--no-use-wheel", "-i", attributes[:python_pypi], "-U", "--build", target, want_pkg)
    end

    dirs = ::Dir.glob(File.join(target, "*"))
    if dirs.length != 1
      raise "Unexpected directory layout after easy_install. Maybe file a bug? The directory is #{build_path}"
    end
    return dirs.first
  end # def download

  def load_package_info(setup_py)
    if !attributes[:python_package_prefix].nil?
      attributes[:python_package_name_prefix] = attributes[:python_package_prefix]
    end

    begin
      json_test_code = [
        "try:",
        "  import json",
        "except ImportError:",
        "  import simplejson as json"
      ].join("\n")
      safesystem("#{attributes[:python_bin]} -c '#{json_test_code}'")
    rescue FPM::Util::ProcessFailed => e
      logger.error("Your python environment is missing json support (either json or simplejson python module). I cannot continue without this.", :python => attributes[:python_bin], :error => e)
      raise FPM::Util::ProcessFailed, "Python (#{attributes[:python_bin]}) is missing simplejson or json modules."
    end

    begin
      safesystem("#{attributes[:python_bin]} -c 'import pkg_resources'")
    rescue FPM::Util::ProcessFailed => e
      logger.error("Your python environment is missing a working setuptools module. I tried to find the 'pkg_resources' module but failed.", :python => attributes[:python_bin], :error => e)
      raise FPM::Util::ProcessFailed, "Python (#{attributes[:python_bin]}) is missing pkg_resources module."
    end

    pylib = File.expand_path(File.dirname(__FILE__))

    setup_dir = File.dirname(setup_py)

    output = ::Dir.chdir(setup_dir) do
      tmp = build_path("metadata.json")
      setup_cmd = "env PYTHONPATH=#{pylib} #{attributes[:python_bin]} " \
        "setup.py --command-packages=pyfpm get_metadata --output=#{tmp}"

      if attributes[:python_obey_requirements_txt?]
        setup_cmd += " --load-requirements-txt"
      end

      logger.info("fetching package metadata", :setup_cmd => setup_cmd)

      success = safesystem(setup_cmd)
      if !success
        logger.error("setup.py get_metadata failed", :command => setup_cmd,
                      :exitcode => $?.exitstatus)
        raise "An unexpected error occurred while processing the setup.py file"
      end
      File.read(tmp)
    end
    logger.debug("result from `setup.py get_metadata`", :data => output)
    metadata = JSON.parse(output)
    logger.info("object output of get_metadata", :json => metadata)

    self.architecture = metadata["architecture"]
    self.description = metadata["description"]
    self.license = metadata["license"].split(/[\r\n]+/).first
    self.version = metadata["version"]
    self.url = metadata["url"]

    if attributes[:python_fix_name?]
      self.name = fix_name(metadata["name"])
    else
      self.name = metadata["name"]
    end

    self.name = self.name.downcase if attributes[:python_downcase_name?]

    if !attributes[:no_auto_depends?] and attributes[:python_dependencies?]
      metadata["dependencies"].each do |dep|
        dep_re = /^([^<>!= ]+)\s*(?:([<>!=]{1,2})\s*(.*))?$/
        match = dep_re.match(dep)
        if match.nil?
          logger.error("Unable to parse dependency", :dependency => dep)
          raise FPM::InvalidPackageConfiguration, "Invalid dependency '#{dep}'"
        end
        name, cmp, version = match.captures

        next if attributes[:python_disable_dependency].include?(name)

        if cmp == "=="
          logger.info("Converting == dependency requirement to =", :dependency => dep )
          cmp = "="
        end

        name = fix_name(name) if attributes[:python_fix_dependencies?]

        name = name.downcase if attributes[:python_downcase_dependencies?]

        self.dependencies << "#{name} #{cmp} #{version}"
      end
    end # if attributes[:python_dependencies?]
  end # def load_package_info

  def fix_name(name)
    if name.start_with?("python")
      return [attributes[:python_package_name_prefix], name.gsub(/^python-/, "")].join("-")
    else
      return [attributes[:python_package_name_prefix], name].join("-")
    end
  end # def fix_name

  def install_to_staging(setup_py)
    project_dir = File.dirname(setup_py)

    prefix = "/"
    prefix = attributes[:prefix] unless attributes[:prefix].nil?

    ::Dir.chdir(project_dir) do
      flags = [ "--root", staging_path ]
      if !attributes[:python_install_lib].nil?
        flags += [ "--install-lib", File.join(prefix, attributes[:python_install_lib]) ]
      elsif !attributes[:prefix].nil?
        flags += [ "--install-lib", File.join(prefix, "lib") ]
      end

      if !attributes[:python_install_data].nil?
        flags += [ "--install-data", File.join(prefix, attributes[:python_install_data]) ]
      elsif !attributes[:prefix].nil?
        flags += [ "--install-data", File.join(prefix, "data") ]
      end

      if !attributes[:python_install_bin].nil?
        flags += [ "--install-scripts", File.join(prefix, attributes[:python_install_bin]) ]
      elsif !attributes[:prefix].nil?
        flags += [ "--install-scripts", File.join(prefix, "bin") ]
      end

      if !attributes[:python_scripts_executable].nil?
        flags += [ "build_scripts", "--executable", attributes[:python_scripts_executable] ]
      end

      safesystem(attributes[:python_bin], "setup.py", "install", *flags)
    end
  end # def install_to_staging

  public(:input)
end # class FPM::Package::Python
