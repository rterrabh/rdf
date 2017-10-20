
require "forwardable"
require "English"
require "date"
require "stringio"

class CSV
  VERSION = "2.4.8".freeze

  class Row
    def initialize(headers, fields, header_row = false)
      @header_row = header_row
      headers.each { |h| h.freeze if h.is_a? String }

      @row = if headers.size >= fields.size
        headers.zip(fields)
      else
        fields.zip(headers).map { |pair| pair.reverse! }
      end
    end

    attr_reader :row
    protected   :row


    extend Forwardable
    def_delegators :@row, :empty?, :length, :size

    def header_row?
      @header_row
    end

    def field_row?
      not header_row?
    end

    def headers
      @row.map { |pair| pair.first }
    end

    def field(header_or_index, minimum_index = 0)
      finder = header_or_index.is_a?(Integer) ? :[] : :assoc
      #nodyna <send-1929> <SD TRIVIAL (public methods)>
      pair   = @row[minimum_index..-1].send(finder, header_or_index)

      pair.nil? ? nil : pair.last
    end
    alias_method :[], :field

    def fetch(header, *varargs)
      raise ArgumentError, "Too many arguments" if varargs.length > 1
      pair = @row.assoc(header)
      if pair
        pair.last
      else
        if block_given?
          yield header
        elsif varargs.empty?
          raise KeyError, "key not found: #{header}"
        else
          varargs.first
        end
      end
    end

    def has_key?(header)
      !!@row.assoc(header)
    end
    alias_method :include?, :has_key?
    alias_method :key?,     :has_key?
    alias_method :member?,  :has_key?

    def []=(*args)
      value = args.pop

      if args.first.is_a? Integer
        if @row[args.first].nil?  # extending past the end with index
          @row[args.first] = [nil, value]
          @row.map! { |pair| pair.nil? ? [nil, nil] : pair }
        else                      # normal index assignment
          @row[args.first][1] = value
        end
      else
        index = index(*args)
        if index.nil?             # appending a field
          self << [args.first, value]
        else                      # normal header assignment
          @row[index][1] = value
        end
      end
    end

    def <<(arg)
      if arg.is_a?(Array) and arg.size == 2  # appending a header and name
        @row << arg
      elsif arg.is_a?(Hash)                  # append header and name pairs
        arg.each { |pair| @row << pair }
      else                                   # append field value
        @row << [nil, arg]
      end

      self  # for chaining
    end

    def push(*args)
      args.each { |arg| self << arg }

      self  # for chaining
    end

    def delete(header_or_index, minimum_index = 0)
      if header_or_index.is_a? Integer                 # by index
        @row.delete_at(header_or_index)
      elsif i = index(header_or_index, minimum_index)  # by header
        @row.delete_at(i)
      else
        [ ]
      end
    end

    def delete_if(&block)
      @row.delete_if(&block)

      self  # for chaining
    end

    def fields(*headers_and_or_indices)
      if headers_and_or_indices.empty?  # return all fields--no arguments
        @row.map { |pair| pair.last }
      else                              # or work like values_at()
        headers_and_or_indices.inject(Array.new) do |all, h_or_i|
          all + if h_or_i.is_a? Range
            index_begin = h_or_i.begin.is_a?(Integer) ? h_or_i.begin :
                                                        index(h_or_i.begin)
            index_end   = h_or_i.end.is_a?(Integer)   ? h_or_i.end :
                                                        index(h_or_i.end)
            new_range   = h_or_i.exclude_end? ? (index_begin...index_end) :
                                                (index_begin..index_end)
            fields.values_at(new_range)
          else
            [field(*Array(h_or_i))]
          end
        end
      end
    end
    alias_method :values_at, :fields

    def index(header, minimum_index = 0)
      index = headers[minimum_index..-1].index(header)
      index.nil? ? nil : index + minimum_index
    end

    def header?(name)
      headers.include? name
    end
    alias_method :include?, :header?

    def field?(data)
      fields.include? data
    end

    include Enumerable

    def each(&block)
      @row.each(&block)

      self  # for chaining
    end

    def ==(other)
      return @row == other.row if other.is_a? CSV::Row
      @row == other
    end

    def to_hash
      Hash[*@row.inject(Array.new) { |ary, pair| ary.push(*pair) }]
    end

    def to_csv(options = Hash.new)
      fields.to_csv(options)
    end
    alias_method :to_s, :to_csv

    def inspect
      str = ["#<", self.class.to_s]
      each do |header, field|
        str << " " << (header.is_a?(Symbol) ? header.to_s : header.inspect) <<
               ":" << field.inspect
      end
      str << ">"
      begin
        str.join('')
      rescue  # any encoding error
        str.map do |s|
          e = Encoding::Converter.asciicompat_encoding(s.encoding)
          e ? s.encode(e) : s.force_encoding("ASCII-8BIT")
        end.join('')
      end
    end
  end

  class Table
    def initialize(array_of_rows)
      @table = array_of_rows
      @mode  = :col_or_row
    end

    attr_reader :mode

    attr_reader :table
    protected   :table


    extend Forwardable
    def_delegators :@table, :empty?, :length, :size

    def by_col
      self.class.new(@table.dup).by_col!
    end

    def by_col!
      @mode = :col

      self
    end

    def by_col_or_row
      self.class.new(@table.dup).by_col_or_row!
    end

    def by_col_or_row!
      @mode = :col_or_row

      self
    end

    def by_row
      self.class.new(@table.dup).by_row!
    end

    def by_row!
      @mode = :row

      self
    end

    def headers
      if @table.empty?
        Array.new
      else
        @table.first.headers
      end
    end

    def [](index_or_header)
      if @mode == :row or  # by index
         (@mode == :col_or_row and index_or_header.is_a? Integer)
        @table[index_or_header]
      else                 # by header
        @table.map { |row| row[index_or_header] }
      end
    end

    def []=(index_or_header, value)
      if @mode == :row or  # by index
         (@mode == :col_or_row and index_or_header.is_a? Integer)
        if value.is_a? Array
          @table[index_or_header] = Row.new(headers, value)
        else
          @table[index_or_header] = value
        end
      else                 # set column
        if value.is_a? Array  # multiple values
          @table.each_with_index do |row, i|
            if row.header_row?
              row[index_or_header] = index_or_header
            else
              row[index_or_header] = value[i]
            end
          end
        else                  # repeated value
          @table.each do |row|
            if row.header_row?
              row[index_or_header] = index_or_header
            else
              row[index_or_header] = value
            end
          end
        end
      end
    end

    def values_at(*indices_or_headers)
      if @mode == :row or  # by indices
         ( @mode == :col_or_row and indices_or_headers.all? do |index|
                                      index.is_a?(Integer)         or
                                      ( index.is_a?(Range)         and
                                        index.first.is_a?(Integer) and
                                        index.last.is_a?(Integer) )
                                    end )
        @table.values_at(*indices_or_headers)
      else                 # by headers
        @table.map { |row| row.values_at(*indices_or_headers) }
      end
    end

    def <<(row_or_array)
      if row_or_array.is_a? Array  # append Array
        @table << Row.new(headers, row_or_array)
      else                         # append Row
        @table << row_or_array
      end

      self  # for chaining
    end

    def push(*rows)
      rows.each { |row| self << row }

      self  # for chaining
    end

    def delete(index_or_header)
      if @mode == :row or  # by index
         (@mode == :col_or_row and index_or_header.is_a? Integer)
        @table.delete_at(index_or_header)
      else                 # by header
        @table.map { |row| row.delete(index_or_header).last }
      end
    end

    def delete_if(&block)
      if @mode == :row or @mode == :col_or_row  # by index
        @table.delete_if(&block)
      else                                      # by header
        to_delete = Array.new
        headers.each_with_index do |header, i|
          to_delete << header if block[[header, self[header]]]
        end
        to_delete.map { |header| delete(header) }
      end

      self  # for chaining
    end

    include Enumerable

    def each(&block)
      if @mode == :col
        headers.each { |header| block[[header, self[header]]] }
      else
        @table.each(&block)
      end

      self  # for chaining
    end

    def ==(other)
      @table == other.table
    end

    def to_a
      @table.inject([headers]) do |array, row|
        if row.header_row?
          array
        else
          array + [row.fields]
        end
      end
    end

    def to_csv(options = Hash.new)
      wh = options.fetch(:write_headers, true)
      @table.inject(wh ? [headers.to_csv(options)] : [ ]) do |rows, row|
        if row.header_row?
          rows
        else
          rows + [row.fields.to_csv(options)]
        end
      end.join('')
    end
    alias_method :to_s, :to_csv

    def inspect
      "#<#{self.class} mode:#{@mode} row_count:#{to_a.size}>".encode("US-ASCII")
    end
  end

  class MalformedCSVError < RuntimeError; end

  FieldInfo = Struct.new(:index, :line, :header)

  DateMatcher     = / \A(?: (\w+,?\s+)?\w+\s+\d{1,2},?\s+\d{2,4} |
                            \d{4}-\d{2}-\d{2} )\z /x
  DateTimeMatcher =
    / \A(?: (\w+,?\s+)?\w+\s+\d{1,2}\s+\d{1,2}:\d{1,2}:\d{1,2},?\s+\d{2,4} |
            \d{4}-\d{2}-\d{2}\s\d{2}:\d{2}:\d{2} )\z /x

  ConverterEncoding = Encoding.find("UTF-8")

  Converters  = { integer:   lambda { |f|
                    Integer(f.encode(ConverterEncoding)) rescue f
                  },
                  float:     lambda { |f|
                    Float(f.encode(ConverterEncoding)) rescue f
                  },
                  numeric:   [:integer, :float],
                  date:      lambda { |f|
                    begin
                      e = f.encode(ConverterEncoding)
                      e =~ DateMatcher ? Date.parse(e) : f
                    rescue  # encoding conversion or date parse errors
                      f
                    end
                  },
                  date_time: lambda { |f|
                    begin
                      e = f.encode(ConverterEncoding)
                      e =~ DateTimeMatcher ? DateTime.parse(e) : f
                    rescue  # encoding conversion or date parse errors
                      f
                    end
                  },
                  all:       [:date_time, :numeric] }

  HeaderConverters = {
    downcase: lambda { |h| h.encode(ConverterEncoding).downcase },
    symbol:   lambda { |h|
      h.encode(ConverterEncoding).downcase.strip.gsub(/\s+/, "_").
                                                 gsub(/\W+/, "").to_sym
    }
  }

  DEFAULT_OPTIONS = { col_sep:            ",",
                      row_sep:            :auto,
                      quote_char:         '"',
                      field_size_limit:   nil,
                      converters:         nil,
                      unconverted_fields: nil,
                      headers:            false,
                      return_headers:     false,
                      header_converters:  nil,
                      skip_blanks:        false,
                      force_quotes:       false,
                      skip_lines:         nil }.freeze

  def self.instance(data = $stdout, options = Hash.new)
    sig = [data.object_id] +
          options.values_at(*DEFAULT_OPTIONS.keys.sort_by { |sym| sym.to_s })

    @@instances ||= Hash.new
    instance    =   (@@instances[sig] ||= new(data, options))

    if block_given?
      yield instance  # run block, if given, returning result
    else
      instance        # or return the instance
    end
  end

  def self.filter(*args)
    in_options, out_options = Hash.new, {row_sep: $INPUT_RECORD_SEPARATOR}
    if args.last.is_a? Hash
      args.pop.each do |key, value|
        case key.to_s
        when /\Ain(?:put)?_(.+)\Z/
          in_options[$1.to_sym] = value
        when /\Aout(?:put)?_(.+)\Z/
          out_options[$1.to_sym] = value
        else
          in_options[key]  = value
          out_options[key] = value
        end
      end
    end
    input  = new(args.shift || ARGF,    in_options)
    output = new(args.shift || $stdout, out_options)

    input.each do |row|
      yield row
      output << row
    end
  end

  def self.foreach(path, options = Hash.new, &block)
    return to_enum(__method__, path, options) unless block
    open(path, options) do |csv|
      csv.each(&block)
    end
  end

  def self.generate(*args)
    if args.first.is_a? String
      io = StringIO.new(args.shift)
      io.seek(0, IO::SEEK_END)
      args.unshift(io)
    else
      encoding = args[-1][:encoding] if args.last.is_a?(Hash)
      str      = ""
      str.force_encoding(encoding) if encoding
      args.unshift(str)
    end
    csv = new(*args)  # wrap
    yield csv         # yield for appending
    csv.string        # return final String
  end

  def self.generate_line(row, options = Hash.new)
    options  = {row_sep: $INPUT_RECORD_SEPARATOR}.merge(options)
    encoding = options.delete(:encoding)
    str      = ""
    if encoding
      str.force_encoding(encoding)
    elsif field = row.find { |f| not f.nil? }
      str.force_encoding(String(field).encoding)
    end
    (new(str, options) << row).string
  end

  def self.open(*args)
    options = if args.last.is_a? Hash then args.pop else Hash.new end
    file_opts = {universal_newline: false}.merge(options)
    begin
      f = File.open(*args, file_opts)
    rescue ArgumentError => e
      raise unless /needs binmode/ =~ e.message and args.size == 1
      args << "rb"
      file_opts = {encoding: Encoding.default_external}.merge(file_opts)
      retry
    end
    begin
      csv = new(f, options)
    rescue Exception
      f.close
      raise
    end

    if block_given?
      begin
        yield csv
      ensure
        csv.close
      end
    else
      csv
    end
  end

  def self.parse(*args, &block)
    csv = new(*args)
    if block.nil?  # slurp contents, if no block is given
      begin
        csv.read
      ensure
        csv.close
      end
    else           # or pass each row to a provided block
      csv.each(&block)
    end
  end

  def self.parse_line(line, options = Hash.new)
    new(line, options).shift
  end

  def self.read(path, *options)
    open(path, *options) { |csv| csv.read }
  end

  def self.readlines(*args)
    read(*args)
  end

  def self.table(path, options = Hash.new)
    read( path, { headers:           true,
                  converters:        :numeric,
                  header_converters: :symbol }.merge(options) )
  end

  def initialize(data, options = Hash.new)
    if data.nil?
      raise ArgumentError.new("Cannot parse nil as CSV")
    end

    options = DEFAULT_OPTIONS.merge(options)

    @io       = data.is_a?(String) ? StringIO.new(data) : data
    @encoding = raw_encoding(nil) ||
                ( if encoding = options.delete(:internal_encoding)
                    case encoding
                    when Encoding; encoding
                    else Encoding.find(encoding)
                    end
                  end ) ||
                ( case encoding = options.delete(:encoding)
                  when Encoding; encoding
                  when /\A[^:]+/; Encoding.find($&)
                  end ) ||
                Encoding.default_internal || Encoding.default_external
    @re_esc   =   "\\".encode(@encoding) rescue ""
    @re_chars =   /#{%"[-\\]\\[\\.^$?*+{}()|# \r\n\t\f\v]".encode(@encoding)}/

    init_separators(options)
    init_parsers(options)
    init_converters(options)
    init_headers(options)
    init_comments(options)

    @force_encoding = !!(encoding || options.delete(:encoding))
    options.delete(:internal_encoding)
    options.delete(:external_encoding)
    unless options.empty?
      raise ArgumentError, "Unknown options:  #{options.keys.join(', ')}."
    end

    @lineno = 0
  end

  attr_reader :col_sep
  attr_reader :row_sep
  attr_reader :quote_char
  attr_reader :field_size_limit

  attr_reader :skip_lines

  def converters
    @converters.map do |converter|
      name = Converters.rassoc(converter)
      name ? name.first : converter
    end
  end
  def unconverted_fields?() @unconverted_fields end
  def headers
    @headers || true if @use_headers
  end
  def return_headers?()     @return_headers     end
  def write_headers?()      @write_headers      end
  def header_converters
    @header_converters.map do |converter|
      name = HeaderConverters.rassoc(converter)
      name ? name.first : converter
    end
  end
  def skip_blanks?()        @skip_blanks        end
  def force_quotes?()       @force_quotes       end

  attr_reader :encoding

  attr_reader :lineno


  extend Forwardable
  def_delegators :@io, :binmode, :binmode?, :close, :close_read, :close_write,
                       :closed?, :eof, :eof?, :external_encoding, :fcntl,
                       :fileno, :flock, :flush, :fsync, :internal_encoding,
                       :ioctl, :isatty, :path, :pid, :pos, :pos=, :reopen,
                       :seek, :stat, :string, :sync, :sync=, :tell, :to_i,
                       :to_io, :truncate, :tty?

  def rewind
    @headers = nil
    @lineno  = 0

    @io.rewind
  end


  def <<(row)
    if header_row? and [Array, String].include? @use_headers.class
      parse_headers  # won't read data for Array or String
      self << @headers if @write_headers
    end

    row = case row
          when self.class::Row then row.fields
          when Hash            then @headers.map { |header| row[header] }
          else                      row
          end

    @headers =  row if header_row?
    @lineno  += 1

    output = row.map(&@quote).join(@col_sep) + @row_sep  # quote and separate
    if @io.is_a?(StringIO)             and
       output.encoding != (encoding = raw_encoding)
      if @force_encoding
        output = output.encode(encoding)
      elsif (compatible_encoding = Encoding.compatible?(@io.string, output))
        @io.set_encoding(compatible_encoding)
        @io.seek(0, IO::SEEK_END)
      end
    end
    @io << output

    self  # for chaining
  end
  alias_method :add_row, :<<
  alias_method :puts,    :<<

  def convert(name = nil, &converter)
    add_converter(:converters, self.class::Converters, name, &converter)
  end

  def header_convert(name = nil, &converter)
    add_converter( :header_converters,
                   self.class::HeaderConverters,
                   name,
                   &converter )
  end

  include Enumerable

  def each
    if block_given?
      while row = shift
        yield row
      end
    else
      to_enum
    end
  end

  def read
    rows = to_a
    if @use_headers
      Table.new(rows)
    else
      rows
    end
  end
  alias_method :readlines, :read

  def header_row?
    @use_headers and @headers.nil?
  end

  def shift

    if header_row? and @return_headers and
       [Array, String].include? @use_headers.class
      if @unconverted_fields
        return add_unconverted_fields(parse_headers, Array.new)
      else
        return parse_headers
      end
    end

    in_extended_col = false
    csv             = Array.new

    loop do
      unless parse = @io.gets(@row_sep)
        return nil
      end

      parse.sub!(@parsers[:line_end], "")

      if csv.empty?
        if parse.empty?
          @lineno += 1
          if @skip_blanks
            next
          elsif @unconverted_fields
            return add_unconverted_fields(Array.new, Array.new)
          elsif @use_headers
            return self.class::Row.new(Array.new, Array.new)
          else
            return Array.new
          end
        end
      end

      next if @skip_lines and @skip_lines.match parse

      parts =  parse.split(@col_sep, -1)
      if parts.empty?
        if in_extended_col
          csv[-1] << @col_sep   # will be replaced with a @row_sep after the parts.each loop
        else
          csv << nil
        end
      end

      parts.each do |part|
        if in_extended_col
          if part[-1] == @quote_char && part.count(@quote_char) % 2 != 0
            csv.last << part[0..-2]
            if csv.last =~ @parsers[:stray_quote]
              raise MalformedCSVError,
                    "Missing or stray quote in line #{lineno + 1}"
            end
            csv.last.gsub!(@quote_char * 2, @quote_char)
            in_extended_col = false
          else
            csv.last << part
            csv.last << @col_sep
          end
        elsif part[0] == @quote_char
          if part[-1] != @quote_char || part.count(@quote_char) % 2 != 0
            csv             << part[1..-1]
            csv.last        << @col_sep
            in_extended_col =  true
          else
            csv << part[1..-2]
            if csv.last =~ @parsers[:stray_quote]
              raise MalformedCSVError,
                    "Missing or stray quote in line #{lineno + 1}"
            end
            csv.last.gsub!(@quote_char * 2, @quote_char)
          end
        elsif part =~ @parsers[:quote_or_nl]
          if part =~ @parsers[:nl_or_lf]
            raise MalformedCSVError, "Unquoted fields do not allow " +
                                     "\\r or \\n (line #{lineno + 1})."
          else
            raise MalformedCSVError, "Illegal quoting in line #{lineno + 1}."
          end
        else
          csv << (part.empty? ? nil : part)
        end
      end

      csv[-1][-1] = @row_sep if in_extended_col

      if in_extended_col
        if @io.eof?
          raise MalformedCSVError,
                "Unclosed quoted field on line #{lineno + 1}."
        elsif @field_size_limit and csv.last.size >= @field_size_limit
          raise MalformedCSVError, "Field size exceeded on line #{lineno + 1}."
        end
      else
        @lineno += 1

        unconverted = csv.dup if @unconverted_fields

        csv = convert_fields(csv) unless @use_headers or @converters.empty?
        csv = parse_headers(csv)  if     @use_headers

        if @unconverted_fields and not csv.respond_to? :unconverted_fields
          add_unconverted_fields(csv, unconverted)
        end

        break csv
      end
    end
  end
  alias_method :gets,     :shift
  alias_method :readline, :shift

  def inspect
    str = ["<#", self.class.to_s, " io_type:"]
    if    @io == $stdout then str << "$stdout"
    elsif @io == $stdin  then str << "$stdin"
    elsif @io == $stderr then str << "$stderr"
    else                      str << @io.class.to_s
    end
    if @io.respond_to?(:path) and (p = @io.path)
      str << " io_path:" << p.inspect
    end
    str << " encoding:" << @encoding.name
    %w[ lineno     col_sep     row_sep
        quote_char skip_blanks ].each do |attr_name|
      #nodyna <instance_variable_get-1930> <IVG MODERATE (array)>
      if a = instance_variable_get("@#{attr_name}")
        str << " " << attr_name << ":" << a.inspect
      end
    end
    if @use_headers
      str << " headers:" << headers.inspect
    end
    str << ">"
    begin
      str.join('')
    rescue  # any encoding error
      str.map do |s|
        e = Encoding::Converter.asciicompat_encoding(s.encoding)
        e ? s.encode(e) : s.force_encoding("ASCII-8BIT")
      end.join('')
    end
  end

  private

  def init_separators(options)
    @col_sep    = options.delete(:col_sep).to_s.encode(@encoding)
    @row_sep    = options.delete(:row_sep)  # encode after resolving :auto
    @quote_char = options.delete(:quote_char).to_s.encode(@encoding)

    if @quote_char.length != 1
      raise ArgumentError, ":quote_char has to be a single character String"
    end

    if @row_sep == :auto
      if [ARGF, STDIN, STDOUT, STDERR].include?(@io) or
         (defined?(Zlib) and @io.class == Zlib::GzipWriter)
        @row_sep = $INPUT_RECORD_SEPARATOR
      else
        begin
          saved_pos = @io.pos
          while @row_sep == :auto
            break unless sample = @io.gets(nil, 1024)
            if sample.end_with? encode_str("\r")
              sample << (@io.gets(nil, 1) || "")
            end

            if sample =~ encode_re("\r\n?|\n")
              @row_sep = $&
              break
            end
          end

          @io.rewind
          while saved_pos > 1024  # avoid loading a lot of data into memory
            @io.read(1024)
            saved_pos -= 1024
          end
          @io.read(saved_pos) if saved_pos.nonzero?
        rescue IOError         # not opened for reading
        rescue NoMethodError   # Zlib::GzipWriter doesn't have some IO methods
        rescue SystemCallError # pipe
        ensure
          @row_sep = $INPUT_RECORD_SEPARATOR if @row_sep == :auto
        end
      end
    end
    @row_sep = @row_sep.to_s.encode(@encoding)

    @force_quotes   = options.delete(:force_quotes)
    do_quote        = lambda do |field|
      field         = String(field)
      encoded_quote = @quote_char.encode(field.encoding)
      encoded_quote                                +
      field.gsub(encoded_quote, encoded_quote * 2) +
      encoded_quote
    end
    quotable_chars = encode_str("\r\n", @col_sep, @quote_char)
    @quote         = if @force_quotes
      do_quote
    else
      lambda do |field|
        if field.nil?  # represent +nil+ fields as empty unquoted fields
          ""
        else
          field = String(field)  # Stringify fields
          if field.empty? or
             field.count(quotable_chars).nonzero?
            do_quote.call(field)
          else
            field  # unquoted field
          end
        end
      end
    end
  end

  def init_parsers(options)
    @skip_blanks      = options.delete(:skip_blanks)
    @field_size_limit = options.delete(:field_size_limit)

    esc_row_sep = escape_re(@row_sep)
    esc_quote   = escape_re(@quote_char)
    @parsers = {
      quote_or_nl:    encode_re("[", esc_quote, "\r\n]"),
      nl_or_lf:       encode_re("[\r\n]"),
      stray_quote:    encode_re( "[^", esc_quote, "]", esc_quote,
                                 "[^", esc_quote, "]" ),
      line_end:       encode_re(esc_row_sep, "\\z"),
      return_newline: encode_str("\r\n")
    }
  end

  def init_converters(options, field_name = :converters)
    if field_name == :converters
      @unconverted_fields = options.delete(:unconverted_fields)
    end

    #nodyna <instance_variable_set-1931> <IVS MODERATE (change-prone variable)>
    instance_variable_set("@#{field_name}", Array.new)

    convert = method(field_name.to_s.sub(/ers\Z/, ""))

    unless options[field_name].nil?
      unless options[field_name].is_a? Array
        options[field_name] = [options[field_name]]
      end
      options[field_name].each do |converter|
        if converter.is_a? Proc  # custom code block
          convert.call(&converter)
        else                     # by name
          convert.call(converter)
        end
      end
    end

    options.delete(field_name)
  end

  def init_headers(options)
    @use_headers    = options.delete(:headers)
    @return_headers = options.delete(:return_headers)
    @write_headers  = options.delete(:write_headers)

    @headers = nil

    init_converters(options, :header_converters)
  end

  def init_comments(options)
    @skip_lines = options.delete(:skip_lines)
    @skip_lines = Regexp.new(@skip_lines) if @skip_lines.is_a? String
    if @skip_lines and not @skip_lines.respond_to?(:match)
      raise ArgumentError, ":skip_lines has to respond to matches"
    end
  end
  def add_converter(var_name, const, name = nil, &converter)
    if name.nil?  # custom converter
      #nodyna <instance_variable_get-1932> <IVG MODERATE (change-prone variable)>
      instance_variable_get("@#{var_name}") << converter
    else          # named converter
      combo = const[name]
      case combo
      when Array  # combo converter
        combo.each do |converter_name|
          add_converter(var_name, const, converter_name)
        end
      else        # individual named converter
        #nodyna <instance_variable_get-1933> <IVG MODERATE (change-prone variable)>
        instance_variable_get("@#{var_name}") << combo
      end
    end
  end

  def convert_fields(fields, headers = false)
    converters = headers ? @header_converters : @converters

    fields.map.with_index do |field, index|
      converters.each do |converter|
        break if field.nil?
        field = if converter.arity == 1  # straight field converter
          converter[field]
        else                             # FieldInfo converter
          header = @use_headers && !headers ? @headers[index] : nil
          converter[field, FieldInfo.new(index, lineno, header)]
        end
        break unless field.is_a? String  # short-circuit pipeline for speed
      end
      field  # final state of each field, converted or original
    end
  end

  def parse_headers(row = nil)
    if @headers.nil?                # header row
      @headers = case @use_headers  # save headers
                 when Array then @use_headers
                 when String
                   self.class.parse_line( @use_headers,
                                          col_sep:    @col_sep,
                                          row_sep:    @row_sep,
                                          quote_char: @quote_char )
                 else            row
                 end

      row      = @headers                       if row.nil?
      @headers = convert_fields(@headers, true)
      @headers.each { |h| h.freeze if h.is_a? String }

      if @return_headers                                     # return headers
        return self.class::Row.new(@headers, row, true)
      elsif not [Array, String].include? @use_headers.class  # skip to field row
        return shift
      end
    end

    self.class::Row.new(@headers, convert_fields(row))  # field row
  end

  def add_unconverted_fields(row, fields)
    class << row
      attr_reader :unconverted_fields
    end
    #nodyna <instance_eval-1934> <IEV COMPLEX (private access)>
    row.instance_eval { @unconverted_fields = fields }
    row
  end

  def escape_re(str)
    str.gsub(@re_chars) {|c| @re_esc + c}
  end

  def encode_re(*chunks)
    Regexp.new(encode_str(*chunks))
  end

  def encode_str(*chunks)
    chunks.map { |chunk| chunk.encode(@encoding.name) }.join('')
  end

  private

  def raw_encoding(default = Encoding::ASCII_8BIT)
    if @io.respond_to? :internal_encoding
      @io.internal_encoding || @io.external_encoding
    elsif @io.is_a? StringIO
      @io.string.encoding
    elsif @io.respond_to? :encoding
      @io.encoding
    else
      default
    end
  end
end

def CSV(*args, &block)
  CSV.instance(*args, &block)
end

class Array # :nodoc:
  def to_csv(options = Hash.new)
    CSV.generate_line(self, options)
  end
end

class String # :nodoc:
  def parse_csv(options = Hash.new)
    CSV.parse_line(self, options)
  end
end
