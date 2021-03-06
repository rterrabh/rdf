class UsageError < RuntimeError; end
class FormulaUnspecifiedError < UsageError; end
class KegUnspecifiedError < UsageError; end

class MultipleVersionsInstalledError < RuntimeError
  attr_reader :name

  def initialize(name)
    @name = name
    super "#{name} has multiple installed versions"
  end
end

class NotAKegError < RuntimeError; end

class NoSuchKegError < RuntimeError
  attr_reader :name

  def initialize(name)
    @name = name
    super "No such keg: #{HOMEBREW_CELLAR}/#{name}"
  end
end

class FormulaValidationError < StandardError
  attr_reader :attr

  def initialize(attr, value)
    @attr = attr
    super "invalid attribute: #{attr} (#{value.inspect})"
  end
end

class FormulaSpecificationError < StandardError; end

class FormulaUnavailableError < RuntimeError
  attr_reader :name
  attr_accessor :dependent

  def initialize(name)
    @name = name
  end

  def dependent_s
    "(dependency of #{dependent})" if dependent && dependent != name
  end

  def to_s
    "No available formula for #{name} #{dependent_s}"
  end
end

class TapFormulaUnavailableError < FormulaUnavailableError
  attr_reader :tap, :user, :repo

  def initialize(tap, name)
    @tap = tap
    @user = tap.user
    @repo = tap.repo
    super "#{tap}/#{name}"
  end

  def to_s
    s = super
    s += "\nPlease tap it and then try again: brew tap #{tap}" unless tap.installed?
    s
  end
end

class TapFormulaAmbiguityError < RuntimeError
  attr_reader :name, :paths, :formulae

  def initialize(name, paths)
    @name = name
    @paths = paths
    @formulae = paths.map do |path|
      path.to_s =~ HOMEBREW_TAP_PATH_REGEX
      "#{$1}/#{$2.sub("homebrew-", "")}/#{path.basename(".rb")}"
    end

    super <<-EOS.undent
      Formulae found in multiple taps: #{formulae.map { |f| "\n       * #{f}" }.join}

      Please use the fully-qualified name e.g. #{formulae.first} to refer the formula.
    EOS
  end
end

class TapFormulaWithOldnameAmbiguityError < RuntimeError
  attr_reader :name, :possible_tap_newname_formulae, :taps

  def initialize(name, possible_tap_newname_formulae)
    @name = name
    @possible_tap_newname_formulae = possible_tap_newname_formulae

    @taps = possible_tap_newname_formulae.map do |newname|
      newname =~ HOMEBREW_TAP_FORMULA_REGEX
      "#{$1}/#{$2}"
    end

    super <<-EOS.undent
      Formulae with '#{name}' old name found in multiple taps: #{taps.map { |t| "\n       * #{t}" }.join}

      Please use the fully-qualified name e.g. #{taps.first}/#{name} to refer the formula or use its new name.
    EOS
  end
end

class TapUnavailableError < RuntimeError
  attr_reader :name

  def initialize(name)
    @name = name

    super <<-EOS.undent
      No available tap #{name}.
    EOS
  end
end

class TapPinStatusError < RuntimeError
  attr_reader :name, :pinned

  def initialize(name, pinned)
    @name = name
    @pinned = pinned

    super pinned ? "#{name} is already pinned." : "#{name} is already unpinned."
  end
end

class OperationInProgressError < RuntimeError
  def initialize(name)
    message = <<-EOS.undent
      Operation already in progress for #{name}
      Another active Homebrew process is already using #{name}.
      Please wait for it to finish or terminate it to continue.
      EOS

    super message
  end
end

class CannotInstallFormulaError < RuntimeError; end

class FormulaInstallationAlreadyAttemptedError < RuntimeError
  def initialize(formula)
    super "Formula installation already attempted: #{formula.full_name}"
  end
end

class UnsatisfiedRequirements < RuntimeError
  def initialize(reqs)
    if reqs.length == 1
      super "An unsatisfied requirement failed this build."
    else
      super "Unsatisfied requirements failed this build."
    end
  end
end

class FormulaConflictError < RuntimeError
  attr_reader :formula, :conflicts

  def initialize(formula, conflicts)
    @formula = formula
    @conflicts = conflicts
    super message
  end

  def conflict_message(conflict)
    message = []
    message << "  #{conflict.name}"
    message << ": because #{conflict.reason}" if conflict.reason
    message.join
  end

  def message
    message = []
    message << "Cannot install #{formula.full_name} because conflicting formulae are installed.\n"
    message.concat conflicts.map { |c| conflict_message(c) } << ""
    message << <<-EOS.undent
      Please `brew unlink #{conflicts.map(&:name)*" "}` before continuing.

      Unlinking removes a formula's symlinks from #{HOMEBREW_PREFIX}. You can
      link the formula again after the install finishes. You can --force this
      install, but the build may fail or cause obscure side-effects in the
      resulting software.
      EOS
    message.join("\n")
  end
end

class BuildError < RuntimeError
  attr_reader :formula, :env

  def initialize(formula, cmd, args, env)
    @formula = formula
    @env = env
    args = args.map { |arg| arg.to_s.gsub " ", "\\ " }.join(" ")
    super "Failed executing: #{cmd} #{args}"
  end

  def issues
    @issues ||= fetch_issues
  end

  def fetch_issues
    GitHub.issues_for_formula(formula.name)
  rescue GitHub::RateLimitExceededError => e
    opoo e.message
    []
  end

  def dump
    if !ARGV.verbose?
      puts
      puts "#{Tty.red}READ THIS#{Tty.reset}: #{Tty.em}#{OS::ISSUES_URL}#{Tty.reset}"
      if formula.tap?
        case formula.tap
        when "homebrew/homebrew-boneyard"
          puts "#{formula} was moved to homebrew-boneyard because it has unfixable issues."
          puts "Please do not file any issues about this. Sorry!"
        else
          puts "If reporting this issue please do so at (not Homebrew/homebrew):"
          puts "  https://github.com/#{formula.tap}/issues"
        end
      end
    else
      require "cmd/config"
      require "cmd/--env"

      ohai "Formula"
      puts "Tap: #{formula.tap}" if formula.tap?
      puts "Path: #{formula.path}"
      ohai "Configuration"
      Homebrew.dump_verbose_config
      ohai "ENV"
      Homebrew.dump_build_env(env)
      puts
      onoe "#{formula.full_name} #{formula.version} did not build"
      unless (logs = Dir["#{formula.logs}/*"]).empty?
        puts "Logs:"
        puts logs.map { |fn| "     #{fn}" }.join("\n")
      end
    end
    puts
    unless RUBY_VERSION < "1.8.7" || issues.empty?
      puts "These open issues may also help:"
      puts issues.map { |i| "#{i["title"]} #{i["html_url"]}" }.join("\n")
    end

    if MacOS.version >= "10.11"
      require "cmd/doctor"
      opoo Checks.new.check_for_unsupported_osx
    end
  end
end

class BuildToolsError < RuntimeError
  def initialize(formulae)
    if formulae.length > 1
      formula_text = "formulae"
      package_text = "binary packages"
    else
      formula_text = "formula"
      package_text = "a binary package"
    end

    if MacOS.version >= "10.10"
      xcode_text = <<-EOS.undent
        To continue, you must install Xcode from the App Store,
        or the CLT by running:
          xcode-select --install
      EOS
    elsif MacOS.version == "10.9"
      xcode_text = <<-EOS.undent
        To continue, you must install Xcode from:
          https://developer.apple.com/downloads/
        or the CLT by running:
          xcode-select --install
      EOS
    elsif MacOS.version >= "10.7"
      xcode_text = <<-EOS.undent
        To continue, you must install Xcode or the CLT from:
          https://developer.apple.com/downloads/
      EOS
    else
      xcode_text = <<-EOS.undent
        To continue, you must install Xcode from:
          https://developer.apple.com/xcode/downloads/
      EOS
    end

    super <<-EOS.undent
      The following #{formula_text}:
      cannot be installed as a #{package_text} and must be built from source.
    EOS
  end
end

class BuildFlagsError < RuntimeError
  def initialize(flags)
    if flags.length > 1
      flag_text = "flags"
      require_text = "require"
    else
      flag_text = "flag"
      require_text = "requires"
    end

    if MacOS.version >= "10.10"
      xcode_text = <<-EOS.undent
        or install Xcode from the App Store, or the CLT by running:
          xcode-select --install
      EOS
    elsif MacOS.version == "10.9"
      xcode_text = <<-EOS.undent
        or install Xcode from:
          https://developer.apple.com/downloads/
        or the CLT by running:
          xcode-select --install
      EOS
    elsif MacOS.version >= "10.7"
      xcode_text = <<-EOS.undent
        or install Xcode or the CLT from:
          https://developer.apple.com/downloads/
      EOS
    else
      xcode_text = <<-EOS.undent
        or install Xcode from:
          https://developer.apple.com/xcode/downloads/
      EOS
    end

    super <<-EOS.undent
      The following #{flag_text}:
      Either remove the #{flag_text} to attempt bottle installation,
    EOS
  end
end

class CompilerSelectionError < RuntimeError
  def initialize(formula)
    super <<-EOS.undent
      To install this formula, you may need to:
        brew install gcc
      EOS
  end
end

class DownloadError < RuntimeError
  def initialize(resource, cause)
    super <<-EOS.undent
      Failed to download resource #{resource.download_name.inspect}
      EOS
    set_backtrace(cause.backtrace)
  end
end

class CurlDownloadStrategyError < RuntimeError
  def initialize(url)
    case url
    when %r{^file://(.+)}
      super "File does not exist: #{$1}"
    else
      super "Download failed: #{url}"
    end
  end
end

class ErrorDuringExecution < RuntimeError
  def initialize(cmd, args = [])
    args = args.map { |a| a.to_s.gsub " ", "\\ " }.join(" ")
    super "Failure while executing: #{cmd} #{args}"
  end
end

class ChecksumMissingError < ArgumentError; end

class ChecksumMismatchError < RuntimeError
  attr_reader :expected, :hash_type

  def initialize(fn, expected, actual)
    @expected = expected
    @hash_type = expected.hash_type.to_s.upcase

    super <<-EOS.undent
      Expected: #{expected}
      Actual: #{actual}
      Archive: #{fn}
      To retry an incomplete download, remove the file above.
      EOS
  end
end

class ResourceMissingError < ArgumentError
  def initialize(formula, resource)
    super "#{formula.full_name} does not define resource #{resource.inspect}"
  end
end

class DuplicateResourceError < ArgumentError
  def initialize(resource)
    super "Resource #{resource.inspect} is defined more than once"
  end
end

class BottleVersionMismatchError < RuntimeError
  def initialize(bottle_file, bottle_version, formula, formula_version)
    super <<-EOS.undent
      Bottle version mismatch
      Bottle: #{bottle_file} (#{bottle_version})
      Formula: #{formula.full_name} (#{formula_version})
    EOS
  end
end
