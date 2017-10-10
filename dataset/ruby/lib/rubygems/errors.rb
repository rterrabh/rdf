
module Gem

  class LoadError < ::LoadError
    attr_accessor :name

    attr_accessor :requirement
  end


  class ConflictError < LoadError


    attr_reader :conflicts


    attr_reader :target

    def initialize target, conflicts
      @target    = target
      @conflicts = conflicts
      @name      = target.name

      reason = conflicts.map { |act, dependencies|
        "#{act.full_name} conflicts with #{dependencies.join(", ")}"
      }.join ", "


      super("Unable to activate #{target.full_name}, because #{reason}")
    end
  end

  class ErrorReason; end

  class PlatformMismatch < ErrorReason

    attr_reader :name

    attr_reader :version

    attr_reader :platforms

    def initialize(name, version)
      @name = name
      @version = version
      @platforms = []
    end

    def add_platform(platform)
      @platforms << platform
    end

    def wordy
      "Found %s (%s), but was for platform%s %s" %
        [@name,
         @version,
         @platforms.size == 1 ? '' : 's',
         @platforms.join(' ,')]
    end
  end


  class SourceFetchProblem < ErrorReason


    def initialize(source, error)
      @source = source
      @error = error
    end


    attr_reader :source


    attr_reader :error


    def wordy
      "Unable to download data from #{@source.uri} - #{@error.message}"
    end


    alias exception error
  end
end
