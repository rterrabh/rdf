

class RDoc::Parser

  @parsers = []

  class << self


    attr_reader :parsers

  end


  attr_reader :file_name


  def self.alias_extension(old_ext, new_ext)
    old_ext = old_ext.sub(/^\.(.*)/, '\1')
    new_ext = new_ext.sub(/^\.(.*)/, '\1')

    parser = can_parse_by_name "xxx.#{old_ext}"
    return false unless parser

    RDoc::Parser.parsers.unshift [/\.#{new_ext}$/, parser]

    true
  end


  def self.binary?(file)
    return false if file =~ /\.(rdoc|txt)$/

    s = File.read(file, 1024) or return false

    have_encoding = s.respond_to? :encoding

    return true if s[0, 2] == Marshal.dump('')[0, 2] or s.index("\x00")

    if have_encoding then
      mode = "r"
      s.sub!(/\A#!.*\n/, '')     # assume shebang line isn't longer than 1024.
      encoding = s[/^\s*\#\s*(?:-\*-\s*)?(?:en)?coding:\s*([^\s;]+?)(?:-\*-|[\s;])/, 1]
      mode = "rb:#{encoding}" if encoding
      s = File.open(file, mode) {|f| f.gets(nil, 1024)}

      not s.valid_encoding?
    else
      if 0.respond_to? :fdiv then
        s.count("\x00-\x7F", "^ -~\t\r\n").fdiv(s.size) > 0.3
      else # HACK 1.8.6
        (s.count("\x00-\x7F", "^ -~\t\r\n").to_f / s.size) > 0.3
      end
    end
  end


  def self.process_directive code_object, directive, value
    warn "RDoc::Parser::process_directive is deprecated and wil be removed in RDoc 4.  Use RDoc::Markup::PreProcess#handle_directive instead" if $-w

    case directive
    when 'nodoc' then
      code_object.document_self = nil # notify nodoc
      code_object.document_children = value.downcase != 'all'
    when 'doc' then
      code_object.document_self = true
      code_object.force_documentation = true
    when 'yield', 'yields' then
      code_object.params.sub!(/,?\s*&\w+/, '') if code_object.params

      code_object.block_params = value
    when 'arg', 'args' then
      code_object.params = value
    end
  end


  def self.zip? file
    zip_signature = File.read file, 4

    zip_signature == "PK\x03\x04" or
      zip_signature == "PK\x05\x06" or
      zip_signature == "PK\x07\x08"
  rescue
    false
  end


  def self.can_parse file_name
    parser = can_parse_by_name file_name

    return if parser == RDoc::Parser::Simple and zip? file_name

    parser
  end


  def self.can_parse_by_name file_name
    _, parser = RDoc::Parser.parsers.find { |regexp,| regexp =~ file_name }

    ext_name = File.extname file_name
    return parser if ext_name.empty?

    if parser == RDoc::Parser::Simple and ext_name !~ /txt|rdoc/ then
      case check_modeline file_name
      when nil, 'rdoc' then # continue
      else return nil
      end
    end

    parser
  rescue Errno::EACCES
  end


  def self.check_modeline file_name
    line = open file_name do |io|
      io.gets
    end

    /-\*-\s*(.*?\S)\s*-\*-/ =~ line

    return nil unless type = $1

    if /;/ =~ type then
      return nil unless /(?:\s|\A)mode:\s*([^\s;]+)/i =~ type
      type = $1
    end

    return nil if /coding:/i =~ type

    type.downcase
  rescue ArgumentError # invalid byte sequence, etc.
  end


  def self.for top_level, file_name, content, options, stats
    return if binary? file_name

    parser = use_markup content

    unless parser then
      parse_name = file_name

      if file_name !~ /\.\w+$/ && content =~ %r{\A#!(.+)} then
        shebang = $1
        case shebang
        when %r{env\s+ruby}, %r{/ruby}
          parse_name = 'dummy.rb'
        end
      end

      parser = can_parse parse_name
    end

    return unless parser

    content = remove_modeline content

    parser.new top_level, file_name, content, options, stats
  rescue SystemCallError
    nil
  end


  def self.parse_files_matching(regexp)
    RDoc::Parser.parsers.unshift [regexp, self]
  end


  def self.remove_modeline content
    content.sub(/\A.*-\*-\s*(.*?\S)\s*-\*-.*\r?\n/, '')
  end


  def self.use_markup content
    markup = content.lines.first(3).grep(/markup:\s+(\w+)/) { $1 }.first

    return unless markup

    return RDoc::Parser::Ruby if %w[tomdoc markdown].include? markup

    markup = Regexp.escape markup

    _, selected = RDoc::Parser.parsers.find do |_, parser|
      /^#{markup}$/i =~ parser.name.sub(/.*:/, '')
    end

    selected
  end


  def initialize top_level, file_name, content, options, stats
    @top_level = top_level
    @top_level.parser = self.class
    @store = @top_level.store

    @file_name = file_name
    @content = content
    @options = options
    @stats = stats

    @preprocess = RDoc::Markup::PreProcess.new @file_name, @options.rdoc_include
    @preprocess.options = @options
  end

  autoload :RubyTools, 'rdoc/parser/ruby_tools'
  autoload :Text,      'rdoc/parser/text'

end

require 'rdoc/parser/simple'
require 'rdoc/parser/c'
require 'rdoc/parser/changelog'
require 'rdoc/parser/markdown'
require 'rdoc/parser/rd'
require 'rdoc/parser/ruby'

