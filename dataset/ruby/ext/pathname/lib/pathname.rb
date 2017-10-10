
require 'pathname.so'

class Pathname

  if RUBY_VERSION < "1.9"
    TO_PATH = :to_str
  else
    TO_PATH = :to_path
  end

  SAME_PATHS = if File::FNM_SYSCASE.nonzero?
    proc {|a, b| a.casecmp(b) == 0}
  else
    proc {|a, b| a == b}
  end


  if File::ALT_SEPARATOR
    SEPARATOR_LIST = "#{Regexp.quote File::ALT_SEPARATOR}#{Regexp.quote File::SEPARATOR}"
    SEPARATOR_PAT = /[#{SEPARATOR_LIST}]/
  else
    SEPARATOR_LIST = "#{Regexp.quote File::SEPARATOR}"
    SEPARATOR_PAT = /#{Regexp.quote File::SEPARATOR}/
  end


  def chop_basename(path) # :nodoc:
    base = File.basename(path)
    if /\A#{SEPARATOR_PAT}?\z/o =~ base
      return nil
    else
      return path[0, path.rindex(base)], base
    end
  end
  private :chop_basename

  def split_names(path) # :nodoc:
    names = []
    while r = chop_basename(path)
      path, basename = r
      names.unshift basename
    end
    return path, names
  end
  private :split_names

  def prepend_prefix(prefix, relpath) # :nodoc:
    if relpath.empty?
      File.dirname(prefix)
    elsif /#{SEPARATOR_PAT}/o =~ prefix
      prefix = File.dirname(prefix)
      prefix = File.join(prefix, "") if File.basename(prefix + 'a') != 'a'
      prefix + relpath
    else
      prefix + relpath
    end
  end
  private :prepend_prefix

  def cleanpath(consider_symlink=false)
    if consider_symlink
      cleanpath_conservative
    else
      cleanpath_aggressive
    end
  end

  def cleanpath_aggressive # :nodoc:
    path = @path
    names = []
    pre = path
    while r = chop_basename(pre)
      pre, base = r
      case base
      when '.'
      when '..'
        names.unshift base
      else
        if names[0] == '..'
          names.shift
        else
          names.unshift base
        end
      end
    end
    pre.tr!(File::ALT_SEPARATOR, File::SEPARATOR) if File::ALT_SEPARATOR
    if /#{SEPARATOR_PAT}/o =~ File.basename(pre)
      names.shift while names[0] == '..'
    end
    self.class.new(prepend_prefix(pre, File.join(*names)))
  end
  private :cleanpath_aggressive

  def has_trailing_separator?(path) # :nodoc:
    if r = chop_basename(path)
      pre, basename = r
      pre.length + basename.length < path.length
    else
      false
    end
  end
  private :has_trailing_separator?

  def add_trailing_separator(path) # :nodoc:
    if File.basename(path + 'a') == 'a'
      path
    else
      File.join(path, "") # xxx: Is File.join is appropriate to add separator?
    end
  end
  private :add_trailing_separator

  def del_trailing_separator(path) # :nodoc:
    if r = chop_basename(path)
      pre, basename = r
      pre + basename
    elsif /#{SEPARATOR_PAT}+\z/o =~ path
      $` + File.dirname(path)[/#{SEPARATOR_PAT}*\z/o]
    else
      path
    end
  end
  private :del_trailing_separator

  def cleanpath_conservative # :nodoc:
    path = @path
    names = []
    pre = path
    while r = chop_basename(pre)
      pre, base = r
      names.unshift base if base != '.'
    end
    pre.tr!(File::ALT_SEPARATOR, File::SEPARATOR) if File::ALT_SEPARATOR
    if /#{SEPARATOR_PAT}/o =~ File.basename(pre)
      names.shift while names[0] == '..'
    end
    if names.empty?
      self.class.new(File.dirname(pre))
    else
      if names.last != '..' && File.basename(path) == '.'
        names << '.'
      end
      result = prepend_prefix(pre, File.join(*names))
      if /\A(?:\.|\.\.)\z/ !~ names.last && has_trailing_separator?(path)
        self.class.new(add_trailing_separator(result))
      else
        self.class.new(result)
      end
    end
  end
  private :cleanpath_conservative

  def parent
    self + '..'
  end

  def mountpoint?
    begin
      stat1 = self.lstat
      stat2 = self.parent.lstat
      stat1.dev == stat2.dev && stat1.ino == stat2.ino ||
        stat1.dev != stat2.dev
    rescue Errno::ENOENT
      false
    end
  end

  def root?
    !!(chop_basename(@path) == nil && /#{SEPARATOR_PAT}/o =~ @path)
  end

  def absolute?
    !relative?
  end

  def relative?
    path = @path
    while r = chop_basename(path)
      path, = r
    end
    path == ''
  end

  def each_filename # :yield: filename
    return to_enum(__method__) unless block_given?
    _, names = split_names(@path)
    names.each {|filename| yield filename }
    nil
  end

  def descend
    vs = []
    ascend {|v| vs << v }
    vs.reverse_each {|v| yield v }
    nil
  end

  def ascend
    path = @path
    yield self
    while r = chop_basename(path)
      path, = r
      break if path.empty?
      yield self.class.new(del_trailing_separator(path))
    end
  end

  def +(other)
    other = Pathname.new(other) unless Pathname === other
    Pathname.new(plus(@path, other.to_s))
  end
  alias / +

  def plus(path1, path2) # -> path # :nodoc:
    prefix2 = path2
    index_list2 = []
    basename_list2 = []
    while r2 = chop_basename(prefix2)
      prefix2, basename2 = r2
      index_list2.unshift prefix2.length
      basename_list2.unshift basename2
    end
    return path2 if prefix2 != ''
    prefix1 = path1
    while true
      while !basename_list2.empty? && basename_list2.first == '.'
        index_list2.shift
        basename_list2.shift
      end
      break unless r1 = chop_basename(prefix1)
      prefix1, basename1 = r1
      next if basename1 == '.'
      if basename1 == '..' || basename_list2.empty? || basename_list2.first != '..'
        prefix1 = prefix1 + basename1
        break
      end
      index_list2.shift
      basename_list2.shift
    end
    r1 = chop_basename(prefix1)
    if !r1 && /#{SEPARATOR_PAT}/o =~ File.basename(prefix1)
      while !basename_list2.empty? && basename_list2.first == '..'
        index_list2.shift
        basename_list2.shift
      end
    end
    if !basename_list2.empty?
      suffix2 = path2[index_list2.first..-1]
      r1 ? File.join(prefix1, suffix2) : prefix1 + suffix2
    else
      r1 ? prefix1 : File.dirname(prefix1)
    end
  end
  private :plus

  def join(*args)
    return self if args.empty?
    result = args.pop
    result = Pathname.new(result) unless Pathname === result
    return result if result.absolute?
    args.reverse_each {|arg|
      arg = Pathname.new(arg) unless Pathname === arg
      result = arg + result
      return result if result.absolute?
    }
    self + result
  end

  def children(with_directory=true)
    with_directory = false if @path == '.'
    result = []
    Dir.foreach(@path) {|e|
      next if e == '.' || e == '..'
      if with_directory
        result << self.class.new(File.join(@path, e))
      else
        result << self.class.new(e)
      end
    }
    result
  end

  def each_child(with_directory=true, &b)
    children(with_directory).each(&b)
  end

  def relative_path_from(base_directory)
    dest_directory = self.cleanpath.to_s
    base_directory = base_directory.cleanpath.to_s
    dest_prefix = dest_directory
    dest_names = []
    while r = chop_basename(dest_prefix)
      dest_prefix, basename = r
      dest_names.unshift basename if basename != '.'
    end
    base_prefix = base_directory
    base_names = []
    while r = chop_basename(base_prefix)
      base_prefix, basename = r
      base_names.unshift basename if basename != '.'
    end
    unless SAME_PATHS[dest_prefix, base_prefix]
      raise ArgumentError, "different prefix: #{dest_prefix.inspect} and #{base_directory.inspect}"
    end
    while !dest_names.empty? &&
          !base_names.empty? &&
          SAME_PATHS[dest_names.first, base_names.first]
      dest_names.shift
      base_names.shift
    end
    if base_names.include? '..'
      raise ArgumentError, "base_directory has ..: #{base_directory.inspect}"
    end
    base_names.fill('..')
    relpath_names = base_names + dest_names
    if relpath_names.empty?
      Pathname.new('.')
    else
      Pathname.new(File.join(*relpath_names))
    end
  end
end


class Pathname    # * Find *
  def find(ignore_error: true) # :yield: pathname
    return to_enum(__method__, ignore_error: ignore_error) unless block_given?
    require 'find'
    if @path == '.'
      Find.find(@path, ignore_error: ignore_error) {|f| yield self.class.new(f.sub(%r{\A\./}, '')) }
    else
      Find.find(@path, ignore_error: ignore_error) {|f| yield self.class.new(f) }
    end
  end
end


class Pathname    # * FileUtils *
  def mkpath
    require 'fileutils'
    FileUtils.mkpath(@path)
    nil
  end

  def rmtree
    require 'fileutils'
    FileUtils.rm_r(@path)
    nil
  end
end

