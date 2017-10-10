
require 'delegate'
require 'tmpdir'

class Tempfile < DelegateClass(File)
  def initialize(basename, tmpdir=nil, mode: 0, **options)
    if block_given?
      warn "Tempfile.new doesn't call the given block."
    end
    @data = []
    @clean_proc = Remover.new(@data)
    ObjectSpace.define_finalizer(self, @clean_proc)

    ::Dir::Tmpname.create(basename, tmpdir, options) do |tmpname, n, opts|
      mode |= File::RDWR|File::CREAT|File::EXCL
      opts[:perm] = 0600
      @data[1] = @tmpfile = File.open(tmpname, mode, opts)
      @data[0] = @tmpname = tmpname
      @mode = mode & ~(File::CREAT|File::EXCL)
      opts.freeze
      @opts = opts
    end

    super(@tmpfile)
  end

  def open
    @tmpfile.close if @tmpfile
    @tmpfile = File.open(@tmpname, @mode, @opts)
    @data[1] = @tmpfile
    __setobj__(@tmpfile)
  end

  def _close    # :nodoc:
    begin
      @tmpfile.close if @tmpfile
    ensure
      @tmpfile = nil
      @data[1] = nil if @data
    end
  end
  protected :_close

  def close(unlink_now=false)
    if unlink_now
      close!
    else
      _close
    end
  end

  def close!
    _close
    unlink
  end

  def unlink
    return unless @tmpname
    begin
      File.unlink(@tmpname)
    rescue Errno::ENOENT
    rescue Errno::EACCES
      return
    end
    @data[0] = @data[1] = nil
    @tmpname = nil
    ObjectSpace.undefine_finalizer(self)
  end
  alias delete unlink

  def path
    @tmpname
  end

  def size
    if @tmpfile
      @tmpfile.flush
      @tmpfile.stat.size
    elsif @tmpname
      File.size(@tmpname)
    else
      0
    end
  end
  alias length size

  def inspect
    if closed?
      "#<#{self.class}:#{path} (closed)>"
    else
      "#<#{self.class}:#{path}>"
    end
  end

  class Remover
    def initialize(data)
      @pid = $$
      @data = data
    end

    def call(*args)
      return if @pid != $$

      path, tmpfile = @data

      STDERR.print "removing ", path, "..." if $DEBUG

      tmpfile.close if tmpfile

      if path
        begin
          File.unlink(path)
        rescue Errno::ENOENT
        end
      end

      STDERR.print "done\n" if $DEBUG
    end
  end

  class << self

    def open(*args)
      tempfile = new(*args)

      if block_given?
        begin
          yield(tempfile)
        ensure
          tempfile.close
        end
      else
        tempfile
      end
    end
  end
end

def Tempfile.create(basename, tmpdir=nil, mode: 0, **options)
  tmpfile = nil
  Dir::Tmpname.create(basename, tmpdir, options) do |tmpname, n, opts|
    mode |= File::RDWR|File::CREAT|File::EXCL
    opts[:perm] = 0600
    tmpfile = File.open(tmpname, mode, opts)
  end
  if block_given?
    begin
      yield tmpfile
    ensure
      tmpfile.close if !tmpfile.closed?
      File.unlink tmpfile
    end
  else
    tmpfile
  end
end
