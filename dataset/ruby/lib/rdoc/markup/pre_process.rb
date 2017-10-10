
class RDoc::Markup::PreProcess


  attr_accessor :options


  def self.post_process &block
    @post_processors << block
  end


  def self.post_processors
    @post_processors
  end


  def self.register directive, &block
    @registered[directive] = block
  end


  def self.registered
    @registered
  end


  def self.reset
    @post_processors = []
    @registered = {}
  end

  reset


  def initialize(input_file_name, include_path)
    @input_file_name = input_file_name
    @include_path = include_path
    @options = nil
  end


  def handle text, code_object = nil, &block
    if RDoc::Comment === text then
      comment = text
      text = text.text
    end

    encoding = text.encoding if defined?(Encoding)

    text.gsub!(/^([ \t]*(?:#|\/?\*)?[ \t]*)(\\?):(\w+):([ \t]*)(.+)?(\r?\n|$)/) do
      next $& if $4.empty? and $5 and $5[0, 1] == ':'

      next "#$1:#$3:#$4#$5\n" unless $2.empty?

      if comment and $3 == 'markup' then
        next "#{$1.strip}\n" unless $5
        comment.format = $5.downcase
        next "#{$1.strip}\n"
      end

      handle_directive $1, $3, $5, code_object, encoding, &block
    end

    comment = text unless comment

    self.class.post_processors.each do |handler|
      handler.call comment, code_object
    end

    text
  end


  def handle_directive prefix, directive, param, code_object = nil,
                       encoding = nil
    blankline = "#{prefix.strip}\n"
    directive = directive.downcase

    case directive
    when 'arg', 'args' then
      return "#{prefix}:#{directive}: #{param}\n" unless code_object

      code_object.params = param

      blankline
    when 'category' then
      if RDoc::Context === code_object then
        section = code_object.add_section param
        code_object.temporary_section = section
      end

      blankline # ignore category if we're not on an RDoc::Context
    when 'doc' then
      return blankline unless code_object
      code_object.document_self = true
      code_object.force_documentation = true

      blankline
    when 'enddoc' then
      return blankline unless code_object
      code_object.done_documenting = true

      blankline
    when 'include' then
      filename = param.split.first
      include_file filename, prefix, encoding
    when 'main' then
      @options.main_page = param if @options.respond_to? :main_page

      blankline
    when 'nodoc' then
      return blankline unless code_object
      code_object.document_self = nil # notify nodoc
      code_object.document_children = param !~ /all/i

      blankline
    when 'notnew', 'not_new', 'not-new' then
      return blankline unless RDoc::AnyMethod === code_object

      code_object.dont_rename_initialize = true

      blankline
    when 'startdoc' then
      return blankline unless code_object

      code_object.start_doc
      code_object.force_documentation = true

      blankline
    when 'stopdoc' then
      return blankline unless code_object

      code_object.stop_doc

      blankline
    when 'title' then
      @options.default_title = param if @options.respond_to? :default_title=

      blankline
    when 'yield', 'yields' then
      return blankline unless code_object
      code_object.params.sub!(/,?\s*&\w+/, '') if code_object.params

      code_object.block_params = param

      blankline
    else
      result = yield directive, param if block_given?

      case result
      when nil then
        code_object.metadata[directive] = param if code_object

        if RDoc::Markup::PreProcess.registered.include? directive then
          handler = RDoc::Markup::PreProcess.registered[directive]
          result = handler.call directive, param if handler
        else
          result = "#{prefix}:#{directive}: #{param}\n"
        end
      when false then
        result = "#{prefix}:#{directive}: #{param}\n"
      end

      result
    end
  end


  def include_file name, indent, encoding
    full_name = find_include_file name

    unless full_name then
      warn "Couldn't find file to include '#{name}' from #{@input_file_name}"
      return ''
    end

    content = RDoc::Encoding.read_file full_name, encoding, true

    content = content.sub(/\A# .*coding[=:].*$/, '').lstrip

    if content =~ /^[^#]/ then
      content.gsub(/^/, indent)
    else
      content.gsub(/^#?/, indent)
    end
  end


  def find_include_file(name)
    to_search = [File.dirname(@input_file_name)].concat @include_path
    to_search.each do |dir|
      full_name = File.join(dir, name)
      stat = File.stat(full_name) rescue next
      return full_name if stat.readable?
    end
    nil
  end

end

