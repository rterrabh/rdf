
class Gem::Package::FileSource < Gem::Package::Source # :nodoc: all

  attr_reader :path

  def initialize path
    @path = path
  end

  def start
    @start ||= File.read path, 20
  end

  def present?
    File.exist? path
  end

  def with_write_io &block
    open path, 'wb', &block
  end

  def with_read_io &block
    open path, 'rb', &block
  end

end

