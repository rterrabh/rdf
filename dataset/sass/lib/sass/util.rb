require 'erb'
require 'set'
require 'enumerator'
require 'stringio'
require 'rbconfig'
require 'uri'
require 'thread'
require 'pathname'

require 'sass/root'
require 'sass/util/subset_map'

module Sass
  module Util
    extend self

    RUBY_VERSION_COMPONENTS = RUBY_VERSION.split(".").map {|s| s.to_i}

    RUBY_ENGINE = defined?(::RUBY_ENGINE) ? ::RUBY_ENGINE : "ruby"

    def scope(file)
      File.join(Sass::ROOT_DIR, file)
    end

    def to_hash(arr)
      ordered_hash(*arr.compact)
    end

    def map_keys(hash)
      map_hash(hash) {|k, v| [yield(k), v]}
    end

    def map_vals(hash)
      rv = hash.class.new
      hash = hash.as_stored if hash.is_a?(NormalizedMap)
      hash.each do |k, v|
        rv[k] = yield(v)
      end
      rv
    end

    def map_hash(hash)
      rv = hash.class.new
      hash.each do |k, v|
        new_key, new_value = yield(k, v)
        new_key = hash.denormalize(new_key) if hash.is_a?(NormalizedMap) && new_key == k
        rv[new_key] = new_value
      end
      rv
    end

    def powerset(arr)
      arr.inject([Set.new].to_set) do |powerset, el|
        new_powerset = Set.new
        powerset.each do |subset|
          new_powerset << subset
          new_powerset << subset + [el]
        end
        new_powerset
      end
    end

    def restrict(value, range)
      [[value, range.first].max, range.last].min
    end

    def round(value)
      return value.ceil if (value % 1) - 0.5 > -0.00001
      value.round
    end

    def merge_adjacent_strings(arr)
      return arr if arr.size < 2
      arr.inject([]) do |a, e|
        if e.is_a?(String)
          if a.last.is_a?(String)
            a.last << e
          else
            a << e.dup
          end
        else
          a << e
        end
        a
      end
    end

    def replace_subseq(arr, subseq, replacement)
      new = []
      matched = []
      i = 0
      arr.each do |elem|
        if elem != subseq[i]
          new.push(*matched)
          matched = []
          i = 0
          new << elem
          next
        end

        if i == subseq.length - 1
          matched = []
          i = 0
          new.push(*replacement)
        else
          matched << elem
          i += 1
        end
      end
      new.push(*matched)
      new
    end

    def intersperse(enum, val)
      enum.inject([]) {|a, e| a << e << val}[0...-1]
    end

    def slice_by(enum)
      results = []
      enum.each do |value|
        key = yield(value)
        if !results.empty? && results.last.first == key
          results.last.last << value
        else
          results << [key, [value]]
        end
      end
      results
    end

    def substitute(ary, from, to)
      res = ary.dup
      i = 0
      while i < res.size
        if res[i...i + from.size] == from
          res[i...i + from.size] = to
        end
        i += 1
      end
      res
    end

    def strip_string_array(arr)
      arr.first.lstrip! if arr.first.is_a?(String)
      arr.last.rstrip! if arr.last.is_a?(String)
      arr
    end

    def paths(arrs)
      arrs.inject([[]]) do |paths, arr|
        flatten(arr.map {|e| paths.map {|path| path + [e]}}, 1)
      end
    end

    def lcs(x, y, &block)
      x = [nil, *x]
      y = [nil, *y]
      block ||= proc {|a, b| a == b && a}
      lcs_backtrace(lcs_table(x, y, &block), x, y, x.size - 1, y.size - 1, &block)
    end

    def hash_to_a(hash)
      return hash.to_a unless ruby1_8? || defined?(Test::Unit)
      hash.sort_by {|k, v| k}
    end

    def group_by_to_a(enum)
      return enum.group_by {|e| yield(e)}.to_a unless ruby1_8?
      order = {}
      arr = []
      groups = enum.group_by do |e|
        res = yield(e)
        unless order.include?(res)
          order[res] = order.size
        end
        res
      end
      groups.each do |key, vals|
        arr[order[key]] = [key, vals]
      end
      arr
    end

    def array_minus(minuend, subtrahend)
      return minuend - subtrahend unless rbx?
      set = Set.new(minuend) - subtrahend
      minuend.select {|e| set.include?(e)}
    end

    def max(val1, val2)
      val1 > val2 ? val1 : val2
    end

    def min(val1, val2)
      val1 <= val2 ? val1 : val2
    end

    def undefined_conversion_error_char(e)
      return e.error_char if rbx?
      return e.error_char.dump unless jruby?
      e.message[/^"[^"]+"/] # "
    end

    def check_range(name, range, value, unit = '')
      grace = (-0.00001..0.00001)
      str = value.to_s
      value = value.value if value.is_a?(Sass::Script::Value::Number)
      return value if range.include?(value)
      return range.first if grace.include?(value - range.first)
      return range.last if grace.include?(value - range.last)
      raise ArgumentError.new(
        "#{name} #{str} must be between #{range.first}#{unit} and #{range.last}#{unit}")
    end

    def subsequence?(seq1, seq2)
      i = j = 0
      loop do
        return true if i == seq1.size
        return false if j == seq2.size
        i += 1 if seq1[i] == seq2[j]
        j += 1
      end
    end

    def caller_info(entry = nil)
      entry ||= caller[1]
      info = entry.scan(/^((?:[A-Za-z]:)?.*?):(-?.*?)(?::.*`(.+)')?$/).first
      info[1] = info[1].to_i
      info[2].sub!(/ \{\}\Z/, '') if info[2]
      info
    end

    def version_gt(v1, v2)
      Array.new([v1.length, v2.length].max).zip(v1.split("."), v2.split(".")) do |_, p1, p2|
        p1 ||= "0"
        p2 ||= "0"
        release1 = p1 =~ /^[0-9]+$/
        release2 = p2 =~ /^[0-9]+$/
        if release1 && release2
          p1, p2 = p1.to_i, p2.to_i
          next if p1 == p2
          return p1 > p2
        elsif !release1 && !release2
          next if p1 == p2
          return p1 > p2
        else
          return release1
        end
      end
    end

    def version_geq(v1, v2)
      version_gt(v1, v2) || !version_gt(v2, v1)
    end

    def abstract(obj)
      raise NotImplementedError.new("#{obj.class} must implement ##{caller_info[2]}")
    end

    def deprecated(obj, message = nil)
      obj_class = obj.is_a?(Class) ? "#{obj}." : "#{obj.class}#"
      full_message = "DEPRECATION WARNING: #{obj_class}#{caller_info[2]} " +
        "will be removed in a future version of Sass.#{("\n" + message) if message}"
      Sass::Util.sass_warn full_message
    end

    def silence_warnings
      the_real_stderr, $stderr = $stderr, StringIO.new
      yield
    ensure
      $stderr = the_real_stderr
    end

    def silence_sass_warnings
      old_level, Sass.logger.log_level = Sass.logger.log_level, :error
      yield
    ensure
      Sass.logger.log_level = old_level
    end

    def sass_warn(msg)
      msg = msg + "\n" unless ruby1?
      Sass.logger.warn(msg)
    end


    def rails_root
      if defined?(::Rails.root)
        return ::Rails.root.to_s if ::Rails.root
        raise "ERROR: Rails.root is nil!"
      end
      return RAILS_ROOT.to_s if defined?(RAILS_ROOT)
      nil
    end

    def rails_env
      return ::Rails.env.to_s if defined?(::Rails.env)
      return RAILS_ENV.to_s if defined?(RAILS_ENV)
      nil
    end

    def ap_geq_3?
      ap_geq?("3.0.0.beta1")
    end

    def ap_geq?(version)
      return false unless defined?(ActionPack) && defined?(ActionPack::VERSION) &&
        defined?(ActionPack::VERSION::STRING)

      version_geq(ActionPack::VERSION::STRING, version)
    end

    def listen_geq_2?
      return @listen_geq_2 unless @listen_geq_2.nil?
      @listen_geq_2 =
        begin
          load_listen!
          require 'listen/version'
          version_geq(::Listen::VERSION, '2.0.0')
        rescue LoadError
          false
        end
    end

    def av_template_class(name)
      #nodyna <const_get-3001> <CG COMPLEX (change-prone variables)>
      return ActionView.const_get("Template#{name}") if ActionView.const_defined?("Template#{name}")
      #nodyna <const_get-3002> <CG COMPLEX (change-prone variables)>
      ActionView::Template.const_get(name.to_s)
    end


    def windows?
      return @windows if defined?(@windows)
      @windows = (RbConfig::CONFIG['host_os'] =~ /mswin|windows|mingw/i)
    end

    def ironruby?
      return @ironruby if defined?(@ironruby)
      @ironruby = RUBY_ENGINE == "ironruby"
    end

    def rbx?
      return @rbx if defined?(@rbx)
      @rbx = RUBY_ENGINE == "rbx"
    end

    def jruby?
      return @jruby if defined?(@jruby)
      @jruby = RUBY_PLATFORM =~ /java/
    end

    def jruby_version
      @jruby_version ||= ::JRUBY_VERSION.split(".").map {|s| s.to_i}
    end

    def glob(path)
      path = path.gsub('\\', '/') if windows?
      if block_given?
        Dir.glob(path) {|f| yield(f)}
      else
        Dir.glob(path)
      end
    end

    def pathname(path)
      path = path.tr("/", "\\") if windows?
      Pathname.new(path)
    end

    def cleanpath(path)
      path = Pathname.new(path) unless path.is_a?(Pathname)
      pathname(path.cleanpath.to_s)
    end

    def realpath(path)
      path = Pathname.new(path) unless path.is_a?(Pathname)

      begin
        path.realpath
      rescue SystemCallError
        path
      end
    end

    def relative_path_from(path, from)
      pathname(path.to_s).relative_path_from(pathname(from.to_s))
    rescue NoMethodError => e
      raise e unless e.name == :zero?

      path = path.to_s
      from = from.to_s
      raise ArgumentError("Incompatible path encodings: #{path.inspect} is #{path.encoding}, " +
        "#{from.inspect} is #{from.encoding}")
    end

    def file_uri_from_path(path)
      path = path.to_s if path.is_a?(Pathname)
      path = path.tr('\\', '/') if windows?
      path = Sass::Util.escape_uri(path)
      return path.start_with?('/') ? "file://" + path : path unless windows?
      return "file:///" + path.tr("\\", "/") if path =~ /^[a-zA-Z]:[\/\\]/
      return "file:" + path.tr("\\", "/") if path =~ /\\\\[^\\]+\\[^\\\/]+/
      path.tr("\\", "/")
    end

    def retry_on_windows
      return yield unless windows?

      begin
        yield
      rescue SystemCallError
        sleep 0.1
        yield
      end
    end

    def destructure(val)
      val || []
    end


    def ruby1?
      return @ruby1 if defined?(@ruby1)
      @ruby1 = RUBY_VERSION_COMPONENTS[0] <= 1
    end

    def ruby1_8?
      return @ruby1_8 if defined?(@ruby1_8)
      @ruby1_8 = ironruby? ||
                   (RUBY_VERSION_COMPONENTS[0] == 1 && RUBY_VERSION_COMPONENTS[1] < 9)
    end

    def ruby1_8_6?
      return @ruby1_8_6 if defined?(@ruby1_8_6)
      @ruby1_8_6 = ruby1_8? && RUBY_VERSION_COMPONENTS[2] < 7
    end

    def ruby1_9_2?
      return @ruby1_9_2 if defined?(@ruby1_9_2)
      @ruby1_9_2 = RUBY_VERSION_COMPONENTS == [1, 9, 2]
    end

    def jruby1_6?
      return @jruby1_6 if defined?(@jruby1_6)
      @jruby1_6 = jruby? && jruby_version[0] == 1 && jruby_version[1] < 7
    end

    def macruby?
      return @macruby if defined?(@macruby)
      @macruby = RUBY_ENGINE == 'macruby'
    end

    require 'sass/util/ordered_hash' if ruby1_8?

    def ordered_hash(*pairs_or_hash)
      if pairs_or_hash.length == 1 && pairs_or_hash.first.is_a?(Hash)
        hash = pairs_or_hash.first
        return hash unless ruby1_8?
        return OrderedHash.new.merge hash
      end

      return Hash[pairs_or_hash] unless ruby1_8?
      (pairs_or_hash.is_a?(NormalizedMap) ? NormalizedMap : OrderedHash)[*flatten(pairs_or_hash, 1)]
    end

    unless ruby1_8?
      CHARSET_REGEXP = /\A@charset "([^"]+)"/
      UTF_8_BOM = "\xEF\xBB\xBF".force_encoding('BINARY')
      UTF_16BE_BOM = "\xFE\xFF".force_encoding('BINARY')
      UTF_16LE_BOM = "\xFF\xFE".force_encoding('BINARY')
    end

    def check_sass_encoding(str)
      if ruby1_8?
        return str.gsub(/\A\xEF\xBB\xBF/, '').gsub(/\r\n?|\f/, "\n"), nil
      end

      binary = str.dup.force_encoding("BINARY")
      if binary.start_with?(UTF_8_BOM)
        binary.slice! 0, UTF_8_BOM.length
        str = binary.force_encoding('UTF-8')
      elsif binary.start_with?(UTF_16BE_BOM)
        binary.slice! 0, UTF_16BE_BOM.length
        str = binary.force_encoding('UTF-16BE')
      elsif binary.start_with?(UTF_16LE_BOM)
        binary.slice! 0, UTF_16LE_BOM.length
        str = binary.force_encoding('UTF-16LE')
      elsif binary =~ CHARSET_REGEXP
        charset = $1.force_encoding('US-ASCII')
        if ruby1_9_2? && charset.downcase == 'utf-16'
          encoding = Encoding.find('UTF-8')
        else
          encoding = Encoding.find(charset)
          if encoding.name == 'UTF-16' || encoding.name == 'UTF-16BE'
            encoding = Encoding.find('UTF-8')
          end
        end
        str = binary.force_encoding(encoding)
      elsif str.encoding.name == "ASCII-8BIT"
        str = str.force_encoding('utf-8')
      end

      find_encoding_error(str) unless str.valid_encoding?

      begin
        return str.encode("UTF-8").gsub(/\r\n?|\f/, "\n").tr("\u0000", "�"), str.encoding
      rescue EncodingError
        find_encoding_error(str)
      end
    end

    def has?(attr, klass, method)
      #nodyna <send-3003> <SD MODERATE (change-prone variables)>
      klass.send("#{attr}s").include?(ruby1_8? ? method.to_s : method.to_sym)
    end

    def enum_with_index(enum)
      ruby1_8? ? enum.enum_with_index : enum.each_with_index
    end

    def enum_cons(enum, n)
      ruby1_8? ? enum.enum_cons(n) : enum.each_cons(n)
    end

    def enum_slice(enum, n)
      ruby1_8? ? enum.enum_slice(n) : enum.each_slice(n)
    end

    def extract!(array)
      out = []
      array.reject! do |e|
        next false unless yield e
        out << e
        true
      end
      out
    end

    def ord(c)
      ruby1_8? ? c[0] : c.ord
    end

    def flatten(arr, n)
      return arr.flatten(n) unless ruby1_8_6?
      return arr if n == 0
      arr.inject([]) {|res, e| e.is_a?(Array) ? res.concat(flatten(e, n - 1)) : res << e}
    end

    def flatten_vertically(arrs)
      result = []
      arrs = arrs.map {|sub| sub.is_a?(Array) ? sub.dup : Array(sub)}
      until arrs.empty?
        arrs.reject! do |arr|
          result << arr.shift
          arr.empty?
        end
      end
      result
    end

    def set_hash(set)
      return set.hash unless ruby1_8_6?
      set.map {|e| e.hash}.uniq.sort.hash
    end

    def set_eql?(set1, set2)
      return set1.eql?(set2) unless ruby1_8_6?
      set1.to_a.uniq.sort_by {|e| e.hash}.eql?(set2.to_a.uniq.sort_by {|e| e.hash})
    end

    def inspect_obj(obj)
      return obj.inspect unless version_geq(RUBY_VERSION, "1.9.2")
      return ':' + inspect_obj(obj.to_s) if obj.is_a?(Symbol)
      return obj.inspect unless obj.is_a?(String)
      '"' + obj.gsub(/[\x00-\x7F]+/) {|s| s.inspect[1...-1]} + '"'
    end

    def extract_values(arr)
      values = []
      mapped = arr.map do |e|
        next e.gsub('{', '{{') if e.is_a?(String)
        values << e
        next "{#{values.count - 1}}"
      end
      return mapped.join, values
    end

    def inject_values(str, values)
      return [str.gsub('{{', '{')] if values.empty?
      result = (str + '{{').scan(/(.*?)(?:(\{\{)|\{(\d+)\})/m).map do |(pre, esc, n)|
        [pre, esc ? '{' : '', n ? values[n.to_i] : '']
      end.flatten(1)
      result[-2] = '' # Get rid of the extra {
      merge_adjacent_strings(result).reject {|s| s == ''}
    end

    def with_extracted_values(arr)
      str, vals = extract_values(arr)
      str = yield str
      inject_values(str, vals)
    end

    def sourcemap_name(css)
      css + ".map"
    end

    def json_escape_string(s)
      return s if s !~ /["\\\b\f\n\r\t]/

      result = ""
      s.split("").each do |c|
        case c
        when '"', "\\"
          result << "\\" << c
        when "\n" then result << "\\n"
        when "\t" then result << "\\t"
        when "\r" then result << "\\r"
        when "\f" then result << "\\f"
        when "\b" then result << "\\b"
        else
          result << c
        end
      end
      result
    end

    def json_value_of(v)
      case v
      when Fixnum
        v.to_s
      when String
        "\"" + json_escape_string(v) + "\""
      when Array
        "[" + v.map {|x| json_value_of(x)}.join(",") + "]"
      when NilClass
        "null"
      when TrueClass
        "true"
      when FalseClass
        "false"
      else
        raise ArgumentError.new("Unknown type: #{v.class.name}")
      end
    end

    VLQ_BASE_SHIFT = 5
    VLQ_BASE = 1 << VLQ_BASE_SHIFT
    VLQ_BASE_MASK = VLQ_BASE - 1
    VLQ_CONTINUATION_BIT = VLQ_BASE

    BASE64_DIGITS = ('A'..'Z').to_a  + ('a'..'z').to_a + ('0'..'9').to_a  + ['+', '/']
    BASE64_DIGIT_MAP = begin
      map = {}
      Sass::Util.enum_with_index(BASE64_DIGITS).map do |digit, i|
        map[digit] = i
      end
      map
    end

    def encode_vlq(value)
      if value < 0
        value = ((-value) << 1) | 1
      else
        value <<= 1
      end

      result = ''
      begin
        digit = value & VLQ_BASE_MASK
        value >>= VLQ_BASE_SHIFT
        if value > 0
          digit |= VLQ_CONTINUATION_BIT
        end
        result << BASE64_DIGITS[digit]
      end while value > 0
      result
    end

    URI_ESCAPE = URI.const_defined?("DEFAULT_PARSER") ? URI::DEFAULT_PARSER : URI

    def escape_uri(string)
      URI_ESCAPE.escape string
    end

    def absolute_path(path, dir_string = nil)
      return File.absolute_path(path, dir_string) unless ruby1_8?

      return File.expand_path(path, dir_string) unless path[0] == ?~
      File.expand_path(File.join(".", path), dir_string)
    end


    class StaticConditionalContext
      def initialize(set)
        @set = set
      end

      def method_missing(name, *args)
        super unless args.empty? && !block_given?
        @set.include?(name)
      end
    end

    ATOMIC_WRITE_MUTEX = Mutex.new

    def atomic_create_and_write_file(filename, perms = 0666)
      require 'tempfile'
      tmpfile = Tempfile.new(File.basename(filename), File.dirname(filename))
      tmpfile.binmode if tmpfile.respond_to?(:binmode)
      result = yield tmpfile
      tmpfile.close
      ATOMIC_WRITE_MUTEX.synchronize do
        begin
          File.chmod(perms & ~File.umask, tmpfile.path)
        rescue Errno::EPERM
        end
        File.rename tmpfile.path, filename
      end
      result
    ensure
      tmpfile.close if tmpfile
      tmpfile.unlink if tmpfile
    end

    def load_listen!
      if defined?(gem)
        begin
          gem 'listen', '>= 1.1.0', '< 3.0.0'
          require 'listen'
        rescue Gem::LoadError
          dir = scope("vendor/listen/lib")
          $LOAD_PATH.unshift dir
          begin
            require 'listen'
          rescue LoadError => e
            if version_geq(RUBY_VERSION, "1.9.3")
              version_constraint = "~> 3.0"
            else
              version_constraint = "~> 1.1"
            end
            e.message << "\n" <<
              "Run \"gem install listen --version '#{version_constraint}'\" to get it."
            raise e
          end
        end
      else
        begin
          require 'listen'
        rescue LoadError => e
          dir = scope("vendor/listen/lib")
          if $LOAD_PATH.include?(dir)
            raise e unless File.exist?(scope(".git"))
            e.message << "\n" <<
              'Run "git submodule update --init" to get the bundled version.'
          else
            $LOAD_PATH.unshift dir
            retry
          end
        end
      end
    end

    private

    def find_encoding_error(str)
      encoding = str.encoding
      cr = Regexp.quote("\r".encode(encoding).force_encoding('BINARY'))
      lf = Regexp.quote("\n".encode(encoding).force_encoding('BINARY'))
      ff = Regexp.quote("\f".encode(encoding).force_encoding('BINARY'))
      line_break = /#{cr}#{lf}?|#{ff}|#{lf}/

      str.force_encoding("binary").split(line_break).each_with_index do |line, i|
        begin
          line.encode(encoding)
        rescue Encoding::UndefinedConversionError => e
          raise Sass::SyntaxError.new(
            "Invalid #{encoding.name} character #{undefined_conversion_error_char(e)}",
            :line => i + 1)
        end
      end

      return str, str.encoding
    end


    def lcs_table(x, y)
      c = Array.new(x.size) {[]}
      x.size.times {|i| c[i][0] = 0}
      y.size.times {|j| c[0][j] = 0}
      (1...x.size).each do |i|
        (1...y.size).each do |j|
          c[i][j] =
            if yield x[i], y[j]
              c[i - 1][j - 1] + 1
            else
              [c[i][j - 1], c[i - 1][j]].max
            end
        end
      end
      c
    end

    def lcs_backtrace(c, x, y, i, j, &block)
      return [] if i == 0 || j == 0
      if (v = yield(x[i], y[j]))
        return lcs_backtrace(c, x, y, i - 1, j - 1, &block) << v
      end

      return lcs_backtrace(c, x, y, i, j - 1, &block) if c[i][j - 1] > c[i - 1][j]
      lcs_backtrace(c, x, y, i - 1, j, &block)
    end

    singleton_methods.each {|method| module_function method}
  end
end

require 'sass/util/multibyte_string_scanner'
require 'sass/util/normalized_map'
require 'sass/util/cross_platform_random'
