class BuildOptions
  def initialize(args, options)
    @args = args
    @options = options
  end

  def include?(name)
    @args.include?("--#{name}")
  end

  def with?(val)
    name = val.respond_to?(:option_name) ? val.option_name : val

    if option_defined? "with-#{name}"
      include? "with-#{name}"
    elsif option_defined? "without-#{name}"
      !include? "without-#{name}"
    else
      false
    end
  end

  def without?(name)
    !with? name
  end

  def bottle?
    include? "build-bottle"
  end

  def head?
    include? "HEAD"
  end

  def devel?
    include? "devel"
  end

  def stable?
    !(head? || devel?)
  end

  def universal?
    include?("universal") && option_defined?("universal")
  end

  def cxx11?
    include?("c++11") && option_defined?("c++11")
  end

  def build_32_bit?
    include?("32-bit") && option_defined?("32-bit")
  end

  def used_options
    @options & @args
  end

  def unused_options
    @options - @args
  end

  private

  def option_defined?(name)
    @options.include? name
  end
end
