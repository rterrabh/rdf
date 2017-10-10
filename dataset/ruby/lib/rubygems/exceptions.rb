
class Gem::Exception < RuntimeError


  attr_accessor :source_exception # :nodoc:

end

class Gem::CommandLineError < Gem::Exception; end

class Gem::DependencyError < Gem::Exception; end

class Gem::DependencyRemovalException < Gem::Exception; end


class Gem::DependencyResolutionError < Gem::DependencyError

  attr_reader :conflict

  def initialize conflict
    @conflict = conflict
    a, b = conflicting_dependencies

    super "conflicting dependencies #{a} and #{b}\n#{@conflict.explanation}"
  end

  def conflicting_dependencies
    @conflict.conflicting_dependencies
  end

end


class Gem::GemNotInHomeException < Gem::Exception
  attr_accessor :spec
end

class Gem::DocumentError < Gem::Exception; end

class Gem::EndOfYAMLException < Gem::Exception; end


class Gem::FilePermissionError < Gem::Exception

  attr_reader :directory

  def initialize directory
    @directory = directory

    super "You don't have write permissions for the #{directory} directory."
  end

end

class Gem::FormatException < Gem::Exception
  attr_accessor :file_path
end

class Gem::GemNotFoundException < Gem::Exception; end


class Gem::SpecificGemNotFoundException < Gem::GemNotFoundException


  def initialize(name, version, errors=nil)
    super "Could not find a valid gem '#{name}' (#{version}) locally or in a repository"

    @name = name
    @version = version
    @errors = errors
  end


  attr_reader :name


  attr_reader :version


  attr_reader :errors

end


class Gem::ImpossibleDependenciesError < Gem::Exception

  attr_reader :conflicts
  attr_reader :request

  def initialize request, conflicts
    @request   = request
    @conflicts = conflicts

    super build_message
  end

  def build_message # :nodoc:
    requester  = @request.requester
    requester  = requester ? requester.spec.full_name : 'The user'
    dependency = @request.dependency

    message = "#{requester} requires #{dependency} but it conflicted:\n"

    @conflicts.each do |_, conflict|
      message << conflict.explanation
    end

    message
  end

  def dependency
    @request.dependency
  end

end

class Gem::InstallError < Gem::Exception; end

class Gem::InvalidSpecificationException < Gem::Exception; end

class Gem::OperationNotSupportedError < Gem::Exception; end

class Gem::RemoteError < Gem::Exception; end

class Gem::RemoteInstallationCancelled < Gem::Exception; end

class Gem::RemoteInstallationSkipped < Gem::Exception; end

class Gem::RemoteSourceException < Gem::Exception; end


class Gem::RubyVersionMismatch < Gem::Exception; end


class Gem::VerificationError < Gem::Exception; end


class Gem::SystemExitException < SystemExit


  attr_accessor :exit_code


  def initialize(exit_code)
    @exit_code = exit_code

    super "Exiting RubyGems with exit_code #{exit_code}"
  end

end


class Gem::UnsatisfiableDependencyError < Gem::DependencyError


  attr_reader :dependency


  attr_accessor :errors


  def initialize dep, platform_mismatch=nil
    if platform_mismatch and !platform_mismatch.empty?
      plats = platform_mismatch.map { |x| x.platform.to_s }.sort.uniq
      super "Unable to resolve dependency: No match for '#{dep}' on this platform. Found: #{plats.join(', ')}"
    else
      if dep.explicit?
        super "Unable to resolve dependency: user requested '#{dep}'"
      else
        super "Unable to resolve dependency: '#{dep.request_context}' requires '#{dep}'"
      end
    end

    @dependency = dep
    @errors     = []
  end


  def name
    @dependency.name
  end


  def version
    @dependency.requirement
  end

end


Gem::UnsatisfiableDepedencyError = Gem::UnsatisfiableDependencyError # :nodoc:

