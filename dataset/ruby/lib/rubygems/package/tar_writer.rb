
require 'digest'


class Gem::Package::TarWriter

  class FileOverflow < StandardError; end


  class BoundedStream


    attr_reader :limit


    attr_reader :written


    def initialize(io, limit)
      @io = io
      @limit = limit
      @written = 0
    end


    def write(data)
      if data.bytesize + @written > @limit
        raise FileOverflow, "You tried to feed more data than fits in the file."
      end
      @io.write data
      @written += data.bytesize
      data.bytesize
    end

  end


  class RestrictedStream


    def initialize(io)
      @io = io
    end


    def write(data)
      @io.write data
    end

  end


  def self.new(io)
    writer = super

    return writer unless block_given?

    begin
      yield writer
    ensure
      writer.close
    end

    nil
  end


  def initialize(io)
    @io = io
    @closed = false
  end


  def add_file(name, mode) # :yields: io
    check_closed

    raise Gem::Package::NonSeekableIO unless @io.respond_to? :pos=

    name, prefix = split_name name

    init_pos = @io.pos
    @io.write "\0" * 512 # placeholder for the header

    yield RestrictedStream.new(@io) if block_given?

    size = @io.pos - init_pos - 512

    remainder = (512 - (size % 512)) % 512
    @io.write "\0" * remainder

    final_pos = @io.pos
    @io.pos = init_pos

    header = Gem::Package::TarHeader.new :name => name, :mode => mode,
                                         :size => size, :prefix => prefix,
                                         :mtime => Time.now

    @io.write header
    @io.pos = final_pos

    self
  end


  def add_file_digest name, mode, digest_algorithms # :yields: io
    digests = digest_algorithms.map do |digest_algorithm|
      digest = digest_algorithm.new
      digest_name =
        if digest.respond_to? :name then
          digest.name
        else
          /::([^:]+)$/ =~ digest_algorithm.name
          $1
        end

      [digest_name, digest]
    end

    digests = Hash[*digests.flatten]

    add_file name, mode do |io|
      Gem::Package::DigestIO.wrap io, digests do |digest_io|
        yield digest_io
      end
    end

    digests
  end


  def add_file_signed name, mode, signer
    digest_algorithms = [
      signer.digest_algorithm,
      Digest::SHA512,
    ].compact.uniq

    digests = add_file_digest name, mode, digest_algorithms do |io|
      yield io
    end

    signature_digest = digests.values.compact.find do |digest|
      digest_name =
        if digest.respond_to? :name then
          digest.name
        else
          /::([^:]+)$/ =~ digest.class.name
          $1
        end

      digest_name == signer.digest_name
    end

    if signer.key then
      signature = signer.sign signature_digest.digest

      add_file_simple "#{name}.sig", 0444, signature.length do |io|
        io.write signature
      end
    end

    digests
  end


  def add_file_simple(name, mode, size) # :yields: io
    check_closed

    name, prefix = split_name name

    header = Gem::Package::TarHeader.new(:name => name, :mode => mode,
                                         :size => size, :prefix => prefix,
                                         :mtime => Time.now).to_s

    @io.write header
    os = BoundedStream.new @io, size

    yield os if block_given?

    min_padding = size - os.written
    @io.write("\0" * min_padding)

    remainder = (512 - (size % 512)) % 512
    @io.write("\0" * remainder)

    self
  end


  def check_closed
    raise IOError, "closed #{self.class}" if closed?
  end


  def close
    check_closed

    @io.write "\0" * 1024
    flush

    @closed = true
  end


  def closed?
    @closed
  end


  def flush
    check_closed

    @io.flush if @io.respond_to? :flush
  end


  def mkdir(name, mode)
    check_closed

    name, prefix = split_name(name)

    header = Gem::Package::TarHeader.new :name => name, :mode => mode,
                                         :typeflag => "5", :size => 0,
                                         :prefix => prefix,
                                         :mtime => Time.now

    @io.write header

    self
  end


  def split_name(name) # :nodoc:
    if name.bytesize > 256
      raise Gem::Package::TooLongFileName.new("File \"#{name}\" has a too long path (should be 256 or less)")
    end

    if name.bytesize <= 100 then
      prefix = ""
    else
      parts = name.split(/\//)
      newname = parts.pop
      nxt = ""

      loop do
        nxt = parts.pop
        break if newname.bytesize + 1 + nxt.bytesize > 100
        newname = nxt + "/" + newname
      end

      prefix = (parts + [nxt]).join "/"
      name = newname

      if name.bytesize > 100
        raise Gem::Package::TooLongFileName.new("File \"#{prefix}/#{name}\" has a too long name (should be 100 or less)")
      end

      if prefix.bytesize > 155 then
        raise Gem::Package::TooLongFileName.new("File \"#{prefix}/#{name}\" has a too long base path (should be 155 or less)")
      end
    end

    return name, prefix
  end

end

