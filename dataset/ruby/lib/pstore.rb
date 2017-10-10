
require "digest/md5"

class PStore
  RDWR_ACCESS = {mode: IO::RDWR | IO::CREAT | IO::BINARY, encoding: Encoding::ASCII_8BIT}.freeze
  RD_ACCESS = {mode: IO::RDONLY | IO::BINARY, encoding: Encoding::ASCII_8BIT}.freeze
  WR_ACCESS = {mode: IO::WRONLY | IO::CREAT | IO::TRUNC | IO::BINARY, encoding: Encoding::ASCII_8BIT}.freeze

  class Error < StandardError
  end

  attr_accessor :ultra_safe

  def initialize(file, thread_safe = false)
    dir = File::dirname(file)
    unless File::directory? dir
      raise PStore::Error, format("directory %s does not exist", dir)
    end
    if File::exist? file and not File::readable? file
      raise PStore::Error, format("file %s not readable", file)
    end
    @filename = file
    @abort = false
    @ultra_safe = false
    @thread_safe = thread_safe
    @lock = Mutex.new
  end

  def in_transaction
    raise PStore::Error, "not in transaction" unless @lock.locked?
  end
  def in_transaction_wr
    in_transaction
    raise PStore::Error, "in read-only transaction" if @rdonly
  end
  private :in_transaction, :in_transaction_wr

  def [](name)
    in_transaction
    @table[name]
  end
  def fetch(name, default=PStore::Error)
    in_transaction
    unless @table.key? name
      if default == PStore::Error
        raise PStore::Error, format("undefined root name `%s'", name)
      else
        return default
      end
    end
    @table[name]
  end
  def []=(name, value)
    in_transaction_wr
    @table[name] = value
  end
  def delete(name)
    in_transaction_wr
    @table.delete name
  end

  def roots
    in_transaction
    @table.keys
  end
  def root?(name)
    in_transaction
    @table.key? name
  end
  def path
    @filename
  end

  def commit
    in_transaction
    @abort = false
    throw :pstore_abort_transaction
  end
  def abort
    in_transaction
    @abort = true
    throw :pstore_abort_transaction
  end

  def transaction(read_only = false)  # :yields:  pstore
    value = nil
    if !@thread_safe
      raise PStore::Error, "nested transaction" unless @lock.try_lock
    else
      begin
        @lock.lock
      rescue ThreadError
        raise PStore::Error, "nested transaction"
      end
    end
    begin
      @rdonly = read_only
      @abort = false
      file = open_and_lock_file(@filename, read_only)
      if file
        begin
          @table, checksum, original_data_size = load_data(file, read_only)

          catch(:pstore_abort_transaction) do
            value = yield(self)
          end

          if !@abort && !read_only
            save_data(checksum, original_data_size, file)
          end
        ensure
          file.close if !file.closed?
        end
      else
        @table = {}
        catch(:pstore_abort_transaction) do
          value = yield(self)
        end
      end
    ensure
      @lock.unlock
    end
    value
  end

  private
  EMPTY_STRING = ""
  EMPTY_MARSHAL_DATA = Marshal.dump({})
  EMPTY_MARSHAL_CHECKSUM = Digest::MD5.digest(EMPTY_MARSHAL_DATA)

  def open_and_lock_file(filename, read_only)
    if read_only
      begin
        file = File.new(filename, RD_ACCESS)
        begin
          file.flock(File::LOCK_SH)
          return file
        rescue
          file.close
          raise
        end
      rescue Errno::ENOENT
        return nil
      end
    else
      file = File.new(filename, RDWR_ACCESS)
      file.flock(File::LOCK_EX)
      return file
    end
  end

  def load_data(file, read_only)
    if read_only
      begin
        table = load(file)
        raise Error, "PStore file seems to be corrupted." unless table.is_a?(Hash)
      rescue EOFError
        table = {}
      end
      table
    else
      data = file.read
      if data.empty?
        table = {}
        checksum = empty_marshal_checksum
        size = empty_marshal_data.bytesize
      else
        table = load(data)
        checksum = Digest::MD5.digest(data)
        size = data.bytesize
        raise Error, "PStore file seems to be corrupted." unless table.is_a?(Hash)
      end
      data.replace(EMPTY_STRING)
      [table, checksum, size]
    end
  end

  def on_windows?
    is_windows = RUBY_PLATFORM =~ /mswin|mingw|bccwin|wince/
    #nodyna <define_method-2233> <DM MODERATE (events)>
    self.class.__send__(:define_method, :on_windows?) do
      is_windows
    end
    is_windows
  end

  def save_data(original_checksum, original_file_size, file)
    new_data = dump(@table)

    if new_data.bytesize != original_file_size || Digest::MD5.digest(new_data) != original_checksum
      if @ultra_safe && !on_windows?
        save_data_with_atomic_file_rename_strategy(new_data, file)
      else
        save_data_with_fast_strategy(new_data, file)
      end
    end

    new_data.replace(EMPTY_STRING)
  end

  def save_data_with_atomic_file_rename_strategy(data, file)
    temp_filename = "#{@filename}.tmp.#{Process.pid}.#{rand 1000000}"
    temp_file = File.new(temp_filename, WR_ACCESS)
    begin
      temp_file.flock(File::LOCK_EX)
      temp_file.write(data)
      temp_file.flush
      File.rename(temp_filename, @filename)
    rescue
      File.unlink(temp_file) rescue nil
      raise
    ensure
      temp_file.close
    end
  end

  def save_data_with_fast_strategy(data, file)
    file.rewind
    file.write(data)
    file.truncate(data.bytesize)
  end


  def dump(table)  # :nodoc:
    Marshal::dump(table)
  end

  def load(content)  # :nodoc:
    Marshal::load(content)
  end

  def empty_marshal_data
    EMPTY_MARSHAL_DATA
  end
  def empty_marshal_checksum
    EMPTY_MARSHAL_CHECKSUM
  end
end
