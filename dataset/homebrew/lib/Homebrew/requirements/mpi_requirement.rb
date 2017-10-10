require "requirement"

class MPIRequirement < Requirement
  attr_reader :lang_list

  fatal true

  default_formula "open-mpi"

  env :userpaths

  def initialize(*tags)
    @non_functional = []
    @unknown_langs = []
    @lang_list = [:cc, :cxx, :f77, :f90] & tags
    tags -= @lang_list
    super(tags)
  end

  def mpi_wrapper_works?(compiler)
    compiler = which compiler
    return false if compiler.nil? || !compiler.executable?

    quiet_system compiler, "--version"
  end

  def inspect
    "#<#{self.class.name}: #{name.inspect} #{tags.inspect} lang_list=#{@lang_list.inspect}>"
  end

  satisfy do
    @lang_list.each do |lang|
      case lang
      when :cc, :cxx, :f90, :f77
        compiler = "mpi" + lang.to_s
        @non_functional << compiler unless mpi_wrapper_works? compiler
      else
        @unknown_langs << lang.to_s
      end
    end
    @unknown_langs.empty? && @non_functional.empty?
  end

  env do
    @lang_list.each do |lang|
      compiler = "mpi" + lang.to_s
      mpi_path = which compiler

      compiler = "MPIFC" if lang == :f90
      ENV[compiler.upcase] = mpi_path
    end
  end
end
