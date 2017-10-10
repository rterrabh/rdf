require 'tsort'


class RDoc::Parser::C < RDoc::Parser

  parse_files_matching(/\.(?:([CcHh])\1?|c([+xp])\2|y)\z/)

  include RDoc::Text


  attr_reader :classes


  attr_accessor :content


  attr_reader :enclosure_dependencies


  attr_reader :known_classes


  attr_reader :missing_dependencies


  attr_reader :singleton_classes


  attr_reader :top_level


  def initialize top_level, file_name, content, options, stats
    super

    @known_classes = RDoc::KNOWN_CLASSES.dup
    @content = handle_tab_width handle_ifdefs_in @content
    @file_dir = File.dirname @file_name

    @classes           = load_variable_map :c_class_variables
    @singleton_classes = load_variable_map :c_singleton_class_variables

    @methods = Hash.new { |h, f| h[f] = Hash.new { |i, m| i[m] = [] } }

    @missing_dependencies = {}

    @enclosure_dependencies = Hash.new { |h, k| h[k] = [] }
    #nodyna <instance_variable_set-2021> <not yet classified>
    @enclosure_dependencies.instance_variable_set :@missing_dependencies,
                                                  @missing_dependencies

    @enclosure_dependencies.extend TSort

    def @enclosure_dependencies.tsort_each_node &block
      each_key(&block)
    rescue TSort::Cyclic => e
      cycle_vars = e.message.scan(/"(.*?)"/).flatten

      cycle = cycle_vars.sort.map do |var_name|
        delete var_name

        var_name, type, mod_name, = @missing_dependencies[var_name]

        "#{type} #{mod_name} (#{var_name})"
      end.join ', '

      warn "Unable to create #{cycle} due to a cyclic class or module creation"

      retry
    end

    def @enclosure_dependencies.tsort_each_child node, &block
      fetch(node, []).each(&block)
    end
  end


  def deduplicate_call_seq
    @methods.each do |var_name, functions|
      class_name = @known_classes[var_name]
      class_obj  = find_class var_name, class_name

      functions.each_value do |method_names|
        next if method_names.length == 1

        method_names.each do |method_name|
          deduplicate_method_name class_obj, method_name
        end
      end
    end
  end


  def deduplicate_method_name class_obj, method_name # :nodoc:
    return unless
      method = class_obj.method_list.find { |m| m.name == method_name }
    return unless call_seq = method.call_seq

    method_name = method_name[0, 1] if method_name =~ /\A\[/

    entries = call_seq.split "\n"

    matching = entries.select do |entry|
      entry =~ /^\w*\.?#{Regexp.escape method_name}/ or
        entry =~ /\s#{Regexp.escape method_name}\s/
    end

    method.call_seq = matching.join "\n"
  end


  def do_aliases
    @content.scan(/rb_define_alias\s*\(
                   \s*(\w+),
                   \s*"(.+?)",
                   \s*"(.+?)"
                   \s*\)/xm) do |var_name, new_name, old_name|
      class_name = @known_classes[var_name]

      unless class_name then
        @options.warn "Enclosing class or module %p for alias %s %s is not known" % [
          var_name, new_name, old_name]
        next
      end

      class_obj = find_class var_name, class_name

      al = RDoc::Alias.new '', old_name, new_name, ''
      al.singleton = @singleton_classes.key? var_name

      comment = find_alias_comment var_name, new_name, old_name

      comment.normalize

      al.comment = comment

      al.record_location @top_level

      class_obj.add_alias al
      @stats.add_alias al
    end
  end


  def do_attrs
    @content.scan(/rb_attr\s*\(
                   \s*(\w+),
                   \s*([\w"()]+),
                   \s*([01]),
                   \s*([01]),
                   \s*\w+\);/xm) do |var_name, attr_name, read, write|
      handle_attr var_name, attr_name, read, write
    end

    @content.scan(%r%rb_define_attr\(
                             \s*([\w\.]+),
                             \s*"([^"]+)",
                             \s*(\d+),
                             \s*(\d+)\s*\);
                %xm) do |var_name, attr_name, read, write|
      handle_attr var_name, attr_name, read, write
    end
  end


  def do_boot_defclass
    @content.scan(/(\w+)\s*=\s*boot_defclass\s*\(\s*"(\w+?)",\s*(\w+?)\s*\)/) do
      |var_name, class_name, parent|
      parent = nil if parent == "0"
      handle_class_module(var_name, :class, class_name, parent, nil)
    end
  end


  def do_classes
    do_boot_defclass
    do_define_class
    do_define_class_under
    do_singleton_class
    do_struct_define_without_accessor
  end


  def do_constants
    @content.scan(%r%\Wrb_define_
                   ( variable          |
                     readonly_variable |
                     const             |
                     global_const        )
               \s*\(
                 (?:\s*(\w+),)?
                 \s*"(\w+)",
                 \s*(.*?)\s*\)\s*;
                 %xm) do |type, var_name, const_name, definition|
      var_name = "rb_cObject" if !var_name or var_name == "rb_mKernel"
      handle_constants type, var_name, const_name, definition
    end

    @content.scan(%r%
                  \Wrb_curses_define_const
                  \s*\(
                    \s*
                    (\w+)
                    \s*
                  \)
                  \s*;%xm) do |consts|
      const = consts.first

      handle_constants 'const', 'mCurses', const, "UINT2NUM(#{const})"
    end

    @content.scan(%r%
                  \Wrb_file_const
                  \s*\(
                    \s*
                    "([^"]+)",
                    \s*
                    (.*?)
                    \s*
                  \)
                  \s*;%xm) do |name, value|
      handle_constants 'const', 'rb_mFConst', name, value
    end
  end


  def do_define_class
    @content.scan(/([\w\.]+)\s* = \s*rb_define_class\s*
              \(
                 \s*"(\w+)",
                 \s*(\w+)\s*
              \)/mx) do |var_name, class_name, parent|
      handle_class_module(var_name, :class, class_name, parent, nil)
    end
  end


  def do_define_class_under
    @content.scan(/([\w\.]+)\s* =                  # var_name
                   \s*rb_define_class_under\s*
                   \(
                     \s* (\w+),                    # under
                     \s* "(\w+)",                  # class_name
                     \s*
                     (?:
                       ([\w\*\s\(\)\.\->]+) |      # parent_name
                       rb_path2class\("([\w:]+)"\) # path
                     )
                     \s*
                   \)
                  /mx) do |var_name, under, class_name, parent_name, path|
      parent = path || parent_name

      handle_class_module var_name, :class, class_name, parent, under
    end
  end


  def do_define_module
    @content.scan(/(\w+)\s* = \s*rb_define_module\s*\(\s*"(\w+)"\s*\)/mx) do
      |var_name, class_name|
      handle_class_module(var_name, :module, class_name, nil, nil)
    end
  end


  def do_define_module_under
    @content.scan(/(\w+)\s* = \s*rb_define_module_under\s*
              \(
                 \s*(\w+),
                 \s*"(\w+)"
              \s*\)/mx) do |var_name, in_module, class_name|
      handle_class_module(var_name, :module, class_name, nil, in_module)
    end
  end


  def do_includes
    @content.scan(/rb_include_module\s*\(\s*(\w+?),\s*(\w+?)\s*\)/) do |c,m|
      next unless cls = @classes[c]
      m = @known_classes[m] || m

      comment = RDoc::Comment.new '', @top_level
      incl = cls.add_include RDoc::Include.new(m, comment)
      incl.record_location @top_level
    end
  end


  def do_methods
    @content.scan(%r%rb_define_
                   (
                      singleton_method |
                      method           |
                      module_function  |
                      private_method
                   )
                   \s*\(\s*([\w\.]+),
                     \s*"([^"]+)",
                     \s*(?:RUBY_METHOD_FUNC\(|VALUEFUNC\(|\(METHOD\))?(\w+)\)?,
                     \s*(-?\w+)\s*\)
                   (?:;\s*/[*/]\s+in\s+(\w+?\.(?:cpp|c|y)))?
                 %xm) do |type, var_name, meth_name, function, param_count, source_file|

      next if var_name == "ruby_top_self"
      next if var_name == "nstr"

      var_name = "rb_cObject" if var_name == "rb_mKernel"
      handle_method(type, var_name, meth_name, function, param_count,
                    source_file)
    end

    @content.scan(%r%rb_define_global_function\s*\(
                             \s*"([^"]+)",
                             \s*(?:RUBY_METHOD_FUNC\(|VALUEFUNC\()?(\w+)\)?,
                             \s*(-?\w+)\s*\)
                (?:;\s*/[*/]\s+in\s+(\w+?\.[cy]))?
                %xm) do |meth_name, function, param_count, source_file|
      handle_method("method", "rb_mKernel", meth_name, function, param_count,
                    source_file)
    end

    @content.scan(/define_filetest_function\s*\(
                     \s*"([^"]+)",
                     \s*(?:RUBY_METHOD_FUNC\(|VALUEFUNC\()?(\w+)\)?,
                     \s*(-?\w+)\s*\)/xm) do |meth_name, function, param_count|

      handle_method("method", "rb_mFileTest", meth_name, function, param_count)
      handle_method("singleton_method", "rb_cFile", meth_name, function,
                    param_count)
    end
  end


  def do_missing
    return if @missing_dependencies.empty?

    @enclosure_dependencies.tsort.each do |in_module|
      arguments = @missing_dependencies.delete in_module

      next unless arguments # dependency on existing class

      handle_class_module(*arguments)
    end
  end


  def do_modules
    do_define_module
    do_define_module_under
  end


  def do_singleton_class
    @content.scan(/([\w\.]+)\s* = \s*rb_singleton_class\s*
                  \(
                    \s*(\w+)
                  \s*\)/mx) do |sclass_var, class_var|
      handle_singleton sclass_var, class_var
    end
  end


  def do_struct_define_without_accessor
    @content.scan(/([\w\.]+)\s* = \s*rb_struct_define_without_accessor\s*
              \(
                 \s*"(\w+)",  # Class name
                 \s*(\w+),    # Parent class
                 \s*\w+,      # Allocation function
                 (\s*"\w+",)* # Attributes
                 \s*NULL
              \)/mx) do |var_name, class_name, parent|
      handle_class_module(var_name, :class, class_name, parent, nil)
    end
  end


  def find_alias_comment class_name, new_name, old_name
    content =~ %r%((?>/\*.*?\*/\s+))
                  rb_define_alias\(\s*#{Regexp.escape class_name}\s*,
                                   \s*"#{Regexp.escape new_name}"\s*,
                                   \s*"#{Regexp.escape old_name}"\s*\);%xm

    RDoc::Comment.new($1 || '', @top_level)
  end


  def find_attr_comment var_name, attr_name, read = nil, write = nil
    attr_name = Regexp.escape attr_name

    rw = if read and write then
           /\s*#{read}\s*,\s*#{write}\s*/xm
         else
           /.*?/m
         end

    comment = if @content =~ %r%((?>/\*.*?\*/\s+))
                                rb_define_attr\((?:\s*#{var_name},)?\s*
                                                "#{attr_name}"\s*,
                $1
              elsif @content =~ %r%((?>/\*.*?\*/\s+))
                                   rb_attr\(\s*#{var_name}\s*,
                                            \s*#{attr_name}\s*,
                $1
              elsif @content =~ %r%(/\*.*?(?:\s*\*\s*)?)
                                   Document-attr:\s#{attr_name}\s*?\n
                                   ((?>(.|\n)*?\*/))%x then
                "#{$1}\n#{$2}"
              else
                ''
              end

    RDoc::Comment.new comment, @top_level
  end


  def find_body class_name, meth_name, meth_obj, file_content, quiet = false
    case file_content
    when %r%((?>/\*.*?\*/\s*)?)
            ((?:(?:\w+)\s+)?
             (?:intern\s+)?VALUE\s+#{meth_name}
             \s*(\([^)]*\))([^;]|$))%xm then
      comment = RDoc::Comment.new $1, @top_level
      body = $2
      offset, = $~.offset(2)

      comment.remove_private if comment

      body = $& if /#{Regexp.escape body}[^(]*?\{.*?^\}/m =~ file_content


      override_comment = find_override_comment class_name, meth_obj
      comment = override_comment if override_comment

      comment.normalize
      find_modifiers comment, meth_obj if comment

      meth_obj.start_collecting_tokens
      tk = RDoc::RubyToken::Token.new nil, 1, 1
      tk.set_text body
      meth_obj.add_token tk
      meth_obj.comment = comment
      meth_obj.offset  = offset
      meth_obj.line    = file_content[0, offset].count("\n") + 1

      body
    when %r%((?>/\*.*?\*/\s*))^\s*(\#\s*define\s+#{meth_name}\s+(\w+))%m then
      comment = RDoc::Comment.new $1, @top_level
      body = $2
      offset = $~.offset(2).first

      find_body class_name, $3, meth_obj, file_content, true

      comment.normalize
      find_modifiers comment, meth_obj

      meth_obj.start_collecting_tokens
      tk = RDoc::RubyToken::Token.new nil, 1, 1
      tk.set_text body
      meth_obj.add_token tk
      meth_obj.comment = comment
      meth_obj.offset  = offset
      meth_obj.line    = file_content[0, offset].count("\n") + 1

      body
    when %r%^\s*\#\s*define\s+#{meth_name}\s+(\w+)%m then

      body = find_body(class_name, $1, meth_obj, file_content, true)

      return body if body

      @options.warn "No definition for #{meth_name}"
      false
    else # No body, but might still have an override comment
      comment = find_override_comment class_name, meth_obj

      if comment then
        comment.normalize
        find_modifiers comment, meth_obj
        meth_obj.comment = comment

        ''
      else
        @options.warn "No definition for #{meth_name}"
        false
      end
    end
  end


  def find_class(raw_name, name)
    unless @classes[raw_name]
      if raw_name =~ /^rb_m/
        container = @top_level.add_module RDoc::NormalModule, name
      else
        container = @top_level.add_class RDoc::NormalClass, name
      end

      container.record_location @top_level
      @classes[raw_name] = container
    end
    @classes[raw_name]
  end


  def find_class_comment class_name, class_mod
    comment = nil

    if @content =~ %r%
        ((?>/\*.*?\*/\s+))
        (static\s+)?
        void\s+
        Init_#{class_name}\s*(?:_\(\s*)?\(\s*(?:void\s*)?\)%xmi then
      comment = $1.sub(%r%Document-(?:class|module):\s+#{class_name}%, '')
    elsif @content =~ %r%Document-(?:class|module):\s+#{class_name}\s*?
                         (?:<\s+[:,\w]+)?\n((?>.*?\*/))%xm then
      comment = "/*\n#{$1}"
    elsif @content =~ %r%((?>/\*.*?\*/\s+))
                         ([\w\.\s]+\s* = \s+)?rb_define_(class|module)[\t (]*?"(#{class_name})"%xm then
      comment = $1
    elsif @content =~ %r%((?>/\*.*?\*/\s+))
                         ([\w\. \t]+ = \s+)?rb_define_(class|module)_under[\t\w, (]*?"(#{class_name.split('::').last})"%xm then
      comment = $1
    else
      comment = ''
    end

    comment = RDoc::Comment.new comment, @top_level
    comment.normalize

    look_for_directives_in class_mod, comment

    class_mod.add_comment comment, @top_level
  end


  def find_const_comment(type, const_name, class_name = nil)
    comment = if @content =~ %r%((?>^\s*/\*.*?\*/\s+))
                             rb_define_#{type}\((?:\s*(\w+),)?\s*
                                                "#{const_name}"\s*,
                                                .*?\)\s*;%xmi then
                $1
              elsif class_name and
                    @content =~ %r%Document-(?:const|global|variable):\s
                                   \s*?\n((?>.*?\*/))%xm then
                "/*\n#{$1}"
              elsif @content =~ %r%Document-(?:const|global|variable):
                                   \s#{const_name}
                                   \s*?\n((?>.*?\*/))%xm then
                "/*\n#{$1}"
              else
                ''
              end

    RDoc::Comment.new comment, @top_level
  end


  def find_modifiers comment, meth_obj
    comment.normalize
    comment.extract_call_seq meth_obj

    look_for_directives_in meth_obj, comment
  end


  def find_override_comment class_name, meth_obj
    name = Regexp.escape meth_obj.name
    prefix = Regexp.escape meth_obj.name_prefix

    comment = if @content =~ %r%Document-method:
                                \s+#{class_name}#{prefix}#{name}
                                \s*?\n((?>.*?\*/))%xm then
                "/*#{$1}"
              elsif @content =~ %r%Document-method:
                                   \s#{name}\s*?\n((?>.*?\*/))%xm then
                "/*#{$1}"
              end

    return unless comment

    RDoc::Comment.new comment, @top_level
  end


  def handle_attr(var_name, attr_name, read, write)
    rw = ''
    rw << 'R' if '1' == read
    rw << 'W' if '1' == write

    class_name = @known_classes[var_name]

    return unless class_name

    class_obj = find_class var_name, class_name

    return unless class_obj

    comment = find_attr_comment var_name, attr_name
    comment.normalize

    name = attr_name.gsub(/rb_intern\("([^"]+)"\)/, '\1')

    attr = RDoc::Attr.new '', name, rw, comment

    attr.record_location @top_level
    class_obj.add_attribute attr
    @stats.add_attribute attr
  end


  def handle_class_module(var_name, type, class_name, parent, in_module)
    parent_name = @known_classes[parent] || parent

    if in_module then
      enclosure = @classes[in_module] || @store.find_c_enclosure(in_module)

      if enclosure.nil? and enclosure = @known_classes[in_module] then
        enc_type = /^rb_m/ =~ in_module ? :module : :class
        handle_class_module in_module, enc_type, enclosure, nil, nil
        enclosure = @classes[in_module]
      end

      unless enclosure then
        @enclosure_dependencies[in_module] << var_name
        @missing_dependencies[var_name] =
          [var_name, type, class_name, parent, in_module]

        return
      end
    else
      enclosure = @top_level
    end

    if type == :class then
      full_name = if RDoc::ClassModule === enclosure then
                    enclosure.full_name + "::#{class_name}"
                  else
                    class_name
                  end

      if @content =~ %r%Document-class:\s+#{full_name}\s*<\s+([:,\w]+)% then
        parent_name = $1
      end

      cm = enclosure.add_class RDoc::NormalClass, class_name, parent_name
    else
      cm = enclosure.add_module RDoc::NormalModule, class_name
    end

    cm.record_location enclosure.top_level

    find_class_comment cm.full_name, cm

    case cm
    when RDoc::NormalClass
      @stats.add_class cm
    when RDoc::NormalModule
      @stats.add_module cm
    end

    @classes[var_name] = cm
    @known_classes[var_name] = cm.full_name
    @store.add_c_enclosure var_name, cm
  end


  def handle_constants(type, var_name, const_name, definition)
    class_name = @known_classes[var_name]

    return unless class_name

    class_obj = find_class var_name, class_name

    unless class_obj then
      @options.warn 'Enclosing class or module %p is not known' % [const_name]
      return
    end

    comment = find_const_comment type, const_name, class_name
    comment.normalize

    if type.downcase == 'const' then
      no_match, new_definition, new_comment = comment.text.split(/(\A.*):/)

      if no_match and no_match.empty? then
        if new_definition.empty? then # Default to literal C definition
          new_definition = definition
        else
          new_definition.gsub!("\:", ":")
          new_definition.gsub!("\\", '\\')
        end

        new_definition.sub!(/\A(\s+)/, '')

        new_comment = "#{$1}#{new_comment.lstrip}"

        new_comment = RDoc::Comment.new new_comment, @top_level

        con = RDoc::Constant.new const_name, new_definition, new_comment
      else
        con = RDoc::Constant.new const_name, definition, comment
      end
    else
      con = RDoc::Constant.new const_name, definition, comment
    end

    con.record_location @top_level
    @stats.add_constant con
    class_obj.add_constant con
  end


  def handle_ifdefs_in(body)
    body.gsub(/^#ifdef HAVE_PROTOTYPES.*?#else.*?\n(.*?)#endif.*?\n/m, '\1')
  end


  def handle_method(type, var_name, meth_name, function, param_count,
                    source_file = nil)
    class_name = @known_classes[var_name]
    singleton  = @singleton_classes.key? var_name

    @methods[var_name][function] << meth_name

    return unless class_name

    class_obj = find_class var_name, class_name

    if class_obj then
      if meth_name == 'initialize' then
        meth_name = 'new'
        singleton = true
        type = 'method' # force public
      end

      meth_obj = RDoc::AnyMethod.new '', meth_name
      meth_obj.c_function = function
      meth_obj.singleton =
        singleton || %w[singleton_method module_function].include?(type)

      p_count = Integer(param_count) rescue -1

      if source_file then
        file_name = File.join @file_dir, source_file

        if File.exist? file_name then
          file_content = File.read file_name
        else
          @options.warn "unknown source #{source_file} for #{meth_name} in #{@file_name}"
        end
      else
        file_content = @content
      end

      body = find_body class_name, function, meth_obj, file_content

      if body and meth_obj.document_self then
        meth_obj.params = if p_count < -1 then # -2 is Array
                            '(*args)'
                          elsif p_count == -1 then # argc, argv
                            rb_scan_args body
                          else
                            "(#{(1..p_count).map { |i| "p#{i}" }.join ', '})"
                          end


        meth_obj.record_location @top_level
        class_obj.add_method meth_obj
        @stats.add_method meth_obj
        meth_obj.visibility = :private if 'private_method' == type
      end
    end
  end


  def handle_singleton sclass_var, class_var
    class_name = @known_classes[class_var]

    @known_classes[sclass_var]     = class_name
    @singleton_classes[sclass_var] = class_name
  end


  def handle_tab_width(body)
    if /\t/ =~ body
      tab_width = @options.tab_width
      body.split(/\n/).map do |line|
        1 while line.gsub!(/\t+/) do
          ' ' * (tab_width * $&.length - $`.length % tab_width)
        end && $~
        line
      end.join "\n"
    else
      body
    end
  end


  def load_variable_map map_name
    return {} unless files = @store.cache[map_name]
    return {} unless name_map = files[@file_name]

    class_map = {}

    name_map.each do |variable, name|
      next unless mod = @store.find_class_or_module(name)

      class_map[variable] = if map_name == :c_class_variables then
                              mod
                            else
                              name
                            end
      @known_classes[variable] = name
    end

    class_map
  end


  def look_for_directives_in context, comment
    @preprocess.handle comment, context do |directive, param|
      case directive
      when 'main' then
        @options.main_page = param
        ''
      when 'title' then
        @options.default_title = param if @options.respond_to? :default_title=
        ''
      end
    end

    comment
  end


  def rb_scan_args method_body
    method_body =~ /rb_scan_args\((.*?)\)/m
    return '(*args)' unless $1

    $1.split(/,/)[2] =~ /"(.*?)"/ # format argument
    format = $1.split(//)

    lead = opt = trail = 0

    if format.first =~ /\d/ then
      lead = $&.to_i
      format.shift
      if format.first =~ /\d/ then
        opt = $&.to_i
        format.shift
        if format.first =~ /\d/ then
          trail = $&.to_i
          format.shift
          block_arg = true
        end
      end
    end

    if format.first == '*' and not block_arg then
      var = true
      format.shift
      if format.first =~ /\d/ then
        trail = $&.to_i
        format.shift
      end
    end

    if format.first == ':' then
      hash = true
      format.shift
    end

    if format.first == '&' then
      block = true
      format.shift
    end


    args = []
    position = 1

    (1...(position + lead)).each do |index|
      args << "p#{index}"
    end

    position += lead

    (position...(position + opt)).each do |index|
      args << "p#{index} = v#{index}"
    end

    position += opt

    if var then
      args << '*args'
      position += 1
    end

    (position...(position + trail)).each do |index|
      args << "p#{index}"
    end

    position += trail

    if hash then
      args << "p#{position} = {}"
    end

    args << '&block' if block

    "(#{args.join ', '})"
  end


  def remove_commented_out_lines
    @content.gsub!(%r%//.*rb_define_%, '//')
  end


  def scan
    remove_commented_out_lines

    do_modules
    do_classes
    do_missing

    do_constants
    do_methods
    do_includes
    do_aliases
    do_attrs

    deduplicate_call_seq

    @store.add_c_variables self

    @top_level
  end

end

