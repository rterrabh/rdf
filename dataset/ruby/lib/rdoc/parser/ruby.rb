
$TOKEN_DEBUG ||= nil


class RDoc::Parser::Ruby < RDoc::Parser

  parse_files_matching(/\.rbw?$/)

  include RDoc::RubyToken
  include RDoc::TokenStream
  include RDoc::Parser::RubyTools


  NORMAL = "::"


  SINGLE = "<<"


  def initialize(top_level, file_name, content, options, stats)
    super

    @size = 0
    @token_listeners = nil
    @scanner = RDoc::RubyLex.new content, @options
    @scanner.exception_on_syntax_error = false
    @prev_seek = nil
    @markup = @options.markup
    @track_visibility = :nodoc != @options.visibility

    @encoding = nil
    @encoding = @options.encoding if Object.const_defined? :Encoding

    reset
  end


  def get_tkread_clean pattern, replacement # :nodoc:
    read = get_tkread.gsub(pattern, replacement).strip
    return '' if read == ';'
    read
  end


  def get_visibility_information tk, single # :nodoc:
    vis_type  = tk.name
    singleton = single == SINGLE

    vis =
      case vis_type
      when 'private'   then :private
      when 'protected' then :protected
      when 'public'    then :public
      when 'private_class_method' then
        singleton = true
        :private
      when 'public_class_method' then
        singleton = true
        :public
      when 'module_function' then
        singleton = true
        :public
      else
        raise RDoc::Error, "Invalid visibility: #{tk.name}"
      end

    return vis_type, vis, singleton
  end


  def collect_first_comment
    skip_tkspace
    comment = ''
    comment.force_encoding @encoding if @encoding
    first_line = true
    first_comment_tk_class = nil

    tk = get_tk

    while TkCOMMENT === tk
      if first_line and tk.text =~ /\A#!/ then
        skip_tkspace
        tk = get_tk
      elsif first_line and tk.text =~ /\A#\s*-\*-/ then
        first_line = false
        skip_tkspace
        tk = get_tk
      else
        break if first_comment_tk_class and not first_comment_tk_class === tk
        first_comment_tk_class = tk.class

        first_line = false
        comment << tk.text << "\n"
        tk = get_tk

        if TkNL === tk then
          skip_tkspace false
          tk = get_tk
        end
      end
    end

    unget_tk tk

    new_comment comment
  end


  def consume_trailing_spaces # :nodoc:
    get_tkread
    skip_tkspace false
  end


  def create_attr container, single, name, rw, comment # :nodoc:
    att = RDoc::Attr.new get_tkread, name, rw, comment, single == SINGLE
    record_location att

    container.add_attribute att
    @stats.add_attribute att

    att
  end


  def create_module_alias container, constant, rhs_name # :nodoc:
    mod = if rhs_name =~ /^::/ then
            @store.find_class_or_module rhs_name
          else
            container.find_module_named rhs_name
          end

    container.add_module_alias mod, constant.name, @top_level if mod
  end


  def error(msg)
    msg = make_message msg

    abort msg
  end


  def get_bool
    skip_tkspace
    tk = get_tk
    case tk
    when TkTRUE
      true
    when TkFALSE, TkNIL
      false
    else
      unget_tk tk
      true
    end
  end


  def get_class_or_module container, ignore_constants = false
    skip_tkspace
    name_t = get_tk
    given_name = ''

    case name_t
    when TkCOLON2, TkCOLON3 then # bug
      name_t = get_tk
      container = @top_level
      given_name << '::'
    end

    skip_tkspace false
    given_name << name_t.name

    while TkCOLON2 === peek_tk do
      prev_container = container
      container = container.find_module_named name_t.name
      container ||=
        if ignore_constants then
          RDoc::Context.new
        else
          c = prev_container.add_module RDoc::NormalModule, name_t.name
          c.ignore unless prev_container.document_children
          @top_level.add_to_classes_or_modules c
          c
        end

      record_location container

      get_tk
      skip_tkspace false
      name_t = get_tk
      given_name << '::' << name_t.name
    end

    skip_tkspace false

    return [container, name_t, given_name]
  end


  def get_class_specification
    case peek_tk
    when TkSELF then return 'self'
    when TkGVAR then return ''
    end

    res = get_constant

    skip_tkspace false

    get_tkread # empty out read buffer

    tk = get_tk

    case tk
    when TkNL, TkCOMMENT, TkSEMICOLON then
      unget_tk(tk)
      return res
    end

    res += parse_call_parameters(tk)
    res
  end


  def get_constant
    res = ""
    skip_tkspace false
    tk = get_tk

    while TkCOLON2 === tk or TkCOLON3 === tk or TkCONSTANT === tk do
      res += tk.name
      tk = get_tk
    end

    unget_tk(tk)
    res
  end


  def get_constant_with_optional_parens
    skip_tkspace false

    nest = 0

    while TkLPAREN === (tk = peek_tk) or TkfLPAREN === tk do
      get_tk
      skip_tkspace
      nest += 1
    end

    name = get_constant

    while nest > 0
      skip_tkspace
      tk = get_tk
      nest -= 1 if TkRPAREN === tk
    end

    name
  end


  def get_end_token tk # :nodoc:
    case tk
    when TkLPAREN, TkfLPAREN
      TkRPAREN
    when TkRPAREN
      nil
    else
      TkNL
    end
  end


  def get_method_container container, name_t # :nodoc:
    prev_container = container
    container = container.find_module_named(name_t.name)

    unless container then
      constant = prev_container.constants.find do |const|
        const.name == name_t.name
      end

      if constant then
        parse_method_dummy prev_container
        return
      end
    end

    unless container then
      obj = name_t.name.split("::").inject(Object) do |state, item|
        #nodyna <const_get-2022> <CG COMPLEX (array)>
        state.const_get(item)
      end rescue nil

      type = obj.class == Class ? RDoc::NormalClass : RDoc::NormalModule

      unless [Class, Module].include?(obj.class) then
        warn("Couldn't find #{name_t.name}. Assuming it's a module")
      end

      if type == RDoc::NormalClass then
        sclass = obj.superclass ? obj.superclass.name : nil
        container = prev_container.add_class type, name_t.name, sclass
      else
        container = prev_container.add_module type, name_t.name
      end

      record_location container
    end

    container
  end


  def get_symbol_or_name
    tk = get_tk
    case tk
    when TkSYMBOL then
      text = tk.text.sub(/^:/, '')

      if TkASSIGN === peek_tk then
        get_tk
        text << '='
      end

      text
    when TkId, TkOp then
      tk.name
    when TkAMPER,
         TkDSTRING,
         TkSTAR,
         TkSTRING then
      tk.text
    else
      raise RDoc::Error, "Name or symbol expected (got #{tk})"
    end
  end

  def stop_at_EXPR_END # :nodoc:
    @scanner.lex_state == :EXPR_END || !@scanner.continue
  end


  def suppress_parents container, ancestor # :nodoc:
    while container and container != ancestor do
      container.suppress unless container.documented?
      container = container.parent
    end
  end


  def look_for_directives_in context, comment
    @preprocess.handle comment, context do |directive, param|
      case directive
      when 'method', 'singleton-method',
           'attr', 'attr_accessor', 'attr_reader', 'attr_writer' then
        false # handled elsewhere
      when 'section' then
        context.set_current_section param, comment.dup
        comment.text = ''
        break
      end
    end

    remove_private_comments comment
  end


  def make_message message
    prefix = "#{@file_name}:"

    prefix << "#{@scanner.line_no}:#{@scanner.char_no}:" if @scanner

    "#{prefix} #{message}"
  end


  def new_comment comment
    c = RDoc::Comment.new comment, @top_level
    c.format = @markup
    c
  end


  def parse_attr(context, single, tk, comment)
    offset  = tk.seek
    line_no = tk.line_no

    args = parse_symbol_arg 1
    if args.size > 0 then
      name = args[0]
      rw = "R"
      skip_tkspace false
      tk = get_tk

      if TkCOMMA === tk then
        rw = "RW" if get_bool
      else
        unget_tk tk
      end

      att = create_attr context, single, name, rw, comment
      att.offset = offset
      att.line   = line_no

      read_documentation_modifiers att, RDoc::ATTR_MODIFIERS
    else
      warn "'attr' ignored - looks like a variable"
    end
  end


  def parse_attr_accessor(context, single, tk, comment)
    offset  = tk.seek
    line_no = tk.line_no

    args = parse_symbol_arg
    rw = "?"

    tmp = RDoc::CodeObject.new
    read_documentation_modifiers tmp, RDoc::ATTR_MODIFIERS
    return if @track_visibility and not tmp.document_self

    case tk.name
    when "attr_reader"   then rw = "R"
    when "attr_writer"   then rw = "W"
    when "attr_accessor" then rw = "RW"
    else
      rw = '?'
    end

    for name in args
      att = create_attr context, single, name, rw, comment
      att.offset = offset
      att.line   = line_no
    end
  end


  def parse_alias(context, single, tk, comment)
    offset  = tk.seek
    line_no = tk.line_no

    skip_tkspace

    if TkLPAREN === peek_tk then
      get_tk
      skip_tkspace
    end

    new_name = get_symbol_or_name

    @scanner.lex_state = :EXPR_FNAME

    skip_tkspace
    if TkCOMMA === peek_tk then
      get_tk
      skip_tkspace
    end

    begin
      old_name = get_symbol_or_name
    rescue RDoc::Error
      return
    end

    al = RDoc::Alias.new(get_tkread, old_name, new_name, comment,
                         single == SINGLE)
    record_location al
    al.offset = offset
    al.line   = line_no

    read_documentation_modifiers al, RDoc::ATTR_MODIFIERS
    context.add_alias al
    @stats.add_alias al

    al
  end


  def parse_call_parameters(tk)
    end_token = case tk
                when TkLPAREN, TkfLPAREN
                  TkRPAREN
                when TkRPAREN
                  return ""
                else
                  TkNL
                end
    nest = 0

    loop do
      case tk
      when TkSEMICOLON
        break
      when TkLPAREN, TkfLPAREN
        nest += 1
      when end_token
        if end_token == TkRPAREN
          nest -= 1
          break if @scanner.lex_state == :EXPR_END and nest <= 0
        else
          break unless @scanner.continue
        end
      when TkCOMMENT, TkASSIGN, TkOPASGN
        unget_tk(tk)
        break
      when nil then
        break
      end
      tk = get_tk
    end

    get_tkread_clean "\n", " "
  end


  def parse_class container, single, tk, comment
    offset  = tk.seek
    line_no = tk.line_no

    declaration_context = container
    container, name_t, given_name = get_class_or_module container

    cls =
      case name_t
      when TkCONSTANT
        parse_class_regular container, declaration_context, single,
          name_t, given_name, comment
      when TkLSHFT
        case name = get_class_specification
        when 'self', container.name
          parse_statements container, SINGLE
          return # don't update offset or line
        else
          parse_class_singleton container, name, comment
        end
      else
        warn "Expected class name or '<<'. Got #{name_t.class}: #{name_t.text.inspect}"
        return
      end

    cls.offset = offset
    cls.line   = line_no

    cls
  end


  def parse_class_regular container, declaration_context, single, # :nodoc:
                          name_t, given_name, comment
    superclass = '::Object'

    if given_name =~ /^::/ then
      declaration_context = @top_level
      given_name = $'
    end

    if TkLT === peek_tk then
      get_tk
      skip_tkspace
      superclass = get_class_specification
      superclass = '(unknown)' if superclass.empty?
    end

    cls_type = single == SINGLE ? RDoc::SingleClass : RDoc::NormalClass
    cls = declaration_context.add_class cls_type, given_name, superclass
    cls.ignore unless container.document_children

    read_documentation_modifiers cls, RDoc::CLASS_MODIFIERS
    record_location cls

    cls.add_comment comment, @top_level

    @top_level.add_to_classes_or_modules cls
    @stats.add_class cls

    suppress_parents container, declaration_context unless cls.document_self

    parse_statements cls

    cls
  end


  def parse_class_singleton container, name, comment # :nodoc:
    other = @store.find_class_named name

    unless other then
      if name =~ /^::/ then
        name = $'
        container = @top_level
      end

      other = container.add_module RDoc::NormalModule, name
      record_location other

      other.ignore if name.empty?

      other.add_comment comment, @top_level
    end

    unless name =~ /\A(::)?[A-Z]/ then
      other.document_self = nil
      other.document_children = false
      other.clear_comment
    end

    @top_level.add_to_classes_or_modules other
    @stats.add_class other

    read_documentation_modifiers other, RDoc::CLASS_MODIFIERS
    parse_statements(other, SINGLE)

    other
  end


  def parse_constant container, tk, comment, ignore_constants = false
    offset  = tk.seek
    line_no = tk.line_no

    name = tk.name
    skip_tkspace false

    return unless name =~ /^\w+$/

    eq_tk = get_tk

    if TkCOLON2 === eq_tk then
      unget_tk eq_tk
      unget_tk tk

      container, name_t, = get_class_or_module container, ignore_constants

      name = name_t.name

      eq_tk = get_tk
    end

    unless TkASSIGN === eq_tk then
      unget_tk eq_tk
      return false
    end

    if TkGT === peek_tk then
      unget_tk eq_tk
      return
    end

    value = ''
    con = RDoc::Constant.new name, value, comment

    body = parse_constant_body container, con

    return unless body

    value.replace body
    record_location con
    con.offset = offset
    con.line   = line_no
    read_documentation_modifiers con, RDoc::CONSTANT_MODIFIERS

    @stats.add_constant con
    container.add_constant con

    true
  end

  def parse_constant_body container, constant # :nodoc:
    nest     = 0
    rhs_name = ''

    get_tkread

    tk = get_tk

    loop do
      case tk
      when TkSEMICOLON then
        break if nest <= 0
      when TkLPAREN, TkfLPAREN, TkLBRACE, TkfLBRACE, TkLBRACK, TkfLBRACK,
           TkDO, TkIF, TkUNLESS, TkCASE, TkDEF, TkBEGIN then
        nest += 1
      when TkRPAREN, TkRBRACE, TkRBRACK, TkEND then
        nest -= 1
      when TkCOMMENT then
        if nest <= 0 and stop_at_EXPR_END then
          unget_tk tk
          break
        else
          unget_tk tk
          read_documentation_modifiers constant, RDoc::CONSTANT_MODIFIERS
        end
      when TkCONSTANT then
        rhs_name << tk.name

        if nest <= 0 and TkNL === peek_tk then
          create_module_alias container, constant, rhs_name
          break
        end
      when TkNL then
        if nest <= 0 and stop_at_EXPR_END then
          unget_tk tk
          break
        end
      when TkCOLON2, TkCOLON3 then
        rhs_name << '::'
      when nil then
        break
      end
      tk = get_tk
    end

    get_tkread_clean(/^[ \t]+/, '')
  end


  def parse_comment container, tk, comment
    return parse_comment_tomdoc container, tk, comment if @markup == 'tomdoc'
    column  = tk.char_no
    offset  = tk.seek
    line_no = tk.line_no

    text = comment.text

    singleton = !!text.sub!(/(^# +:?)(singleton-)(method:)/, '\1\3')

    co =
      if text.sub!(/^# +:?method: *(\S*).*?\n/i, '') then
        parse_comment_ghost container, text, $1, column, line_no, comment
      elsif text.sub!(/# +:?(attr(_reader|_writer|_accessor)?): *(\S*).*?\n/i, '') then
        parse_comment_attr container, $1, $3, comment
      end

    if co then
      co.singleton = singleton
      co.offset    = offset
      co.line      = line_no
    end

    true
  end


  def parse_comment_attr container, type, name, comment # :nodoc:
    return if name.empty?

    rw = case type
         when 'attr_reader' then 'R'
         when 'attr_writer' then 'W'
         else 'RW'
         end

    create_attr container, NORMAL, name, rw, comment
  end

  def parse_comment_ghost container, text, name, column, line_no, # :nodoc:
                          comment
    name = nil if name.empty?

    meth = RDoc::GhostMethod.new get_tkread, name
    record_location meth

    meth.start_collecting_tokens
    indent = TkSPACE.new 0, 1, 1
    indent.set_text " " * column

    position_comment = TkCOMMENT.new 0, line_no, 1
    position_comment.set_text "# File #{@top_level.relative_name}, line #{line_no}"
    meth.add_tokens [position_comment, NEWLINE_TOKEN, indent]

    meth.params =
      if text.sub!(/^#\s+:?args?:\s*(.*?)\s*$/i, '') then
        $1
      else
        ''
      end

    comment.normalize
    comment.extract_call_seq meth

    return unless meth.name

    container.add_method meth

    meth.comment = comment

    @stats.add_method meth

    meth
  end


  def parse_comment_tomdoc container, tk, comment
    return unless signature = RDoc::TomDoc.signature(comment)
    offset  = tk.seek
    line_no = tk.line_no

    name, = signature.split %r%[ \(]%, 2

    meth = RDoc::GhostMethod.new get_tkread, name
    record_location meth
    meth.offset    = offset
    meth.line      = line_no

    meth.start_collecting_tokens
    indent = TkSPACE.new 0, 1, 1
    indent.set_text " " * offset

    position_comment = TkCOMMENT.new 0, line_no, 1
    position_comment.set_text "# File #{@top_level.relative_name}, line #{line_no}"
    meth.add_tokens [position_comment, NEWLINE_TOKEN, indent]

    meth.call_seq = signature

    comment.normalize

    return unless meth.name

    container.add_method meth

    meth.comment = comment

    @stats.add_method meth
  end


  def parse_extend_or_include klass, container, comment # :nodoc:
    loop do
      skip_tkspace_comment

      name = get_constant_with_optional_parens

      unless name.empty? then
        obj = container.add klass, name, comment
        record_location obj
      end

      return unless TkCOMMA === peek_tk

      get_tk
    end
  end


  def parse_identifier container, single, tk, comment # :nodoc:
    case tk.name
    when 'private', 'protected', 'public', 'private_class_method',
         'public_class_method', 'module_function' then
      parse_visibility container, single, tk
      return true
    when 'attr' then
      parse_attr container, single, tk, comment
    when /^attr_(reader|writer|accessor)$/ then
      parse_attr_accessor container, single, tk, comment
    when 'alias_method' then
      parse_alias container, single, tk, comment
    when 'require', 'include' then
    else
      if comment.text =~ /\A#\#$/ then
        case comment.text
        when /^# +:?attr(_reader|_writer|_accessor)?:/ then
          parse_meta_attr container, single, tk, comment
        else
          method = parse_meta_method container, single, tk, comment
          method.params = container.params if
            container.params
          method.block_params = container.block_params if
            container.block_params
        end
      end
    end

    false
  end


  def parse_meta_attr(context, single, tk, comment)
    args = parse_symbol_arg
    rw = "?"


    tmp = RDoc::CodeObject.new
    read_documentation_modifiers tmp, RDoc::ATTR_MODIFIERS

    if comment.text.sub!(/^# +:?(attr(_reader|_writer|_accessor)?): *(\S*).*?\n/i, '') then
      rw = case $1
           when 'attr_reader' then 'R'
           when 'attr_writer' then 'W'
           else 'RW'
           end
      name = $3 unless $3.empty?
    end

    if name then
      att = create_attr context, single, name, rw, comment
    else
      args.each do |attr_name|
        att = create_attr context, single, attr_name, rw, comment
      end
    end

    att
  end


  def parse_meta_method(container, single, tk, comment)
    column  = tk.char_no
    offset  = tk.seek
    line_no = tk.line_no

    start_collecting_tokens
    add_token tk
    add_token_listener self

    skip_tkspace false

    singleton = !!comment.text.sub!(/(^# +:?)(singleton-)(method:)/, '\1\3')

    name = parse_meta_method_name comment, tk

    return unless name

    meth = RDoc::MetaMethod.new get_tkread, name
    record_location meth
    meth.offset = offset
    meth.line   = line_no
    meth.singleton = singleton

    remove_token_listener self

    meth.start_collecting_tokens
    indent = TkSPACE.new 0, 1, 1
    indent.set_text " " * column

    position_comment = TkCOMMENT.new 0, line_no, 1
    position_comment.value = "# File #{@top_level.relative_name}, line #{line_no}"
    meth.add_tokens [position_comment, NEWLINE_TOKEN, indent]
    meth.add_tokens @token_stream

    parse_meta_method_params container, single, meth, tk, comment

    meth.comment = comment

    @stats.add_method meth

    meth
  end


  def parse_meta_method_name comment, tk # :nodoc:
    if comment.text.sub!(/^# +:?method: *(\S*).*?\n/i, '') then
      return $1 unless $1.empty?
    end

    name_t = get_tk

    case name_t
    when TkSYMBOL then
      name_t.text[1..-1]
    when TkSTRING then
      name_t.value[1..-2]
    when TkASSIGN then # ignore
      remove_token_listener self

      nil
    else
      warn "unknown name token #{name_t.inspect} for meta-method '#{tk.name}'"
      'unknown'
    end
  end


  def parse_meta_method_params container, single, meth, tk, comment # :nodoc:
    token_listener meth do
      meth.params = ''

      comment.normalize
      comment.extract_call_seq meth

      container.add_method meth

      last_tk = tk

      while tk = get_tk do
        case tk
        when TkSEMICOLON then
          break
        when TkNL then
          break unless last_tk and TkCOMMA === last_tk
        when TkSPACE then
        when TkDO then
          parse_statements container, single, meth
          break
        else
          last_tk = tk
        end
      end
    end
  end


  def parse_method(container, single, tk, comment)
    singleton = nil
    added_container = false
    name = nil
    column  = tk.char_no
    offset  = tk.seek
    line_no = tk.line_no

    start_collecting_tokens
    add_token tk

    token_listener self do
      prev_container = container
      name, container, singleton = parse_method_name container
      added_container = container != prev_container
    end

    return unless name

    meth = RDoc::AnyMethod.new get_tkread, name
    meth.singleton = single == SINGLE ? true : singleton

    record_location meth
    meth.offset = offset
    meth.line   = line_no

    meth.start_collecting_tokens
    indent = TkSPACE.new 0, 1, 1
    indent.set_text " " * column

    token = TkCOMMENT.new 0, line_no, 1
    token.set_text "# File #{@top_level.relative_name}, line #{line_no}"
    meth.add_tokens [token, NEWLINE_TOKEN, indent]
    meth.add_tokens @token_stream

    parse_method_params_and_body container, single, meth, added_container

    comment.normalize
    comment.extract_call_seq meth

    meth.comment = comment

    @stats.add_method meth
  end


  def parse_method_params_and_body container, single, meth, added_container
    token_listener meth do
      @scanner.continue = false
      parse_method_parameters meth

      if meth.document_self or not @track_visibility then
        container.add_method meth
      elsif added_container then
        container.document_self = false
      end


      if meth.name == "initialize" && !meth.singleton then
        if meth.dont_rename_initialize then
          meth.visibility = :protected
        else
          meth.singleton = true
          meth.name = "new"
          meth.visibility = :public
        end
      end

      parse_statements container, single, meth
    end
  end


  def parse_method_dummy container
    dummy = RDoc::Context.new
    dummy.parent = container
    dummy.store  = container.store
    skip_method dummy
  end


  def parse_method_name container # :nodoc:
    @scanner.lex_state = :EXPR_FNAME

    skip_tkspace
    name_t = get_tk
    back_tk = skip_tkspace
    singleton = false

    case dot = get_tk
    when TkDOT, TkCOLON2 then
      singleton = true

      name, container = parse_method_name_singleton container, name_t
    else
      unget_tk dot
      back_tk.reverse_each do |token|
        unget_tk token
      end

      name = parse_method_name_regular container, name_t
    end

    return name, container, singleton
  end


  def parse_method_name_regular container, name_t # :nodoc:
    case name_t
    when TkSTAR, TkAMPER then
      name_t.text
    else
      unless name_t.respond_to? :name then
        warn "expected method name token, . or ::, got #{name_t.inspect}"
        skip_method container
        return
      end
      name_t.name
    end
  end


  def parse_method_name_singleton container, name_t # :nodoc:
    @scanner.lex_state = :EXPR_FNAME
    skip_tkspace
    name_t2 = get_tk

    name =
      case name_t
      when TkSELF, TkMOD then
        case name_t2
        when TkfLBRACK then
          get_tk
          '[]'
        else
          name_t2.name
        end
      when TkCONSTANT then
        name = name_t2.name

        container = get_method_container container, name_t

        return unless container

        name
      when TkIDENTIFIER, TkIVAR, TkGVAR then
        parse_method_dummy container

        nil
      when TkTRUE, TkFALSE, TkNIL then
        klass_name = "#{name_t.name.capitalize}Class"
        container = @store.find_class_named klass_name
        container ||= @top_level.add_class RDoc::NormalClass, klass_name

        name_t2.name
      else
        warn "unexpected method name token #{name_t.inspect}"
        skip_method container

        nil
      end

    return name, container
  end


  def parse_method_or_yield_parameters(method = nil,
                                       modifiers = RDoc::METHOD_MODIFIERS)
    skip_tkspace false
    tk = get_tk
    end_token = get_end_token tk
    return '' unless end_token

    nest = 0

    loop do
      case tk
      when TkSEMICOLON then
        break if nest == 0
      when TkLBRACE, TkfLBRACE then
        nest += 1
      when TkRBRACE then
        nest -= 1
        if nest <= 0
          unget_tk(tk) if nest < 0
          break
        end
      when TkLPAREN, TkfLPAREN then
        nest += 1
      when end_token then
        if end_token == TkRPAREN
          nest -= 1
          break if nest <= 0
        else
          break unless @scanner.continue
        end
      when TkRPAREN then
        nest -= 1
      when method && method.block_params.nil? && TkCOMMENT then
        unget_tk tk
        read_documentation_modifiers method, modifiers
        @read.pop
      when TkCOMMENT then
        @read.pop
      when nil then
        break
      end
      tk = get_tk
    end

    get_tkread_clean(/\s+/, ' ')
  end


  def parse_method_parameters method
    res = parse_method_or_yield_parameters method

    res = "(#{res})" unless res =~ /\A\(/
    method.params = res unless method.params

    return if  method.block_params

    skip_tkspace false
    read_documentation_modifiers method, RDoc::METHOD_MODIFIERS
  end


  def parse_module container, single, tk, comment
    container, name_t, = get_class_or_module container

    name = name_t.name

    mod = container.add_module RDoc::NormalModule, name
    mod.ignore unless container.document_children
    record_location mod

    read_documentation_modifiers mod, RDoc::CLASS_MODIFIERS
    mod.add_comment comment, @top_level
    parse_statements mod

    @stats.add_module mod
  end


  def parse_require(context, comment)
    skip_tkspace_comment
    tk = get_tk

    if TkLPAREN === tk then
      skip_tkspace_comment
      tk = get_tk
    end

    name = tk.text if TkSTRING === tk

    if name then
      @top_level.add_require RDoc::Require.new(name, comment)
    else
      unget_tk tk
    end
  end


  def parse_rescue
    skip_tkspace false

    while tk = get_tk
      case tk
      when TkNL, TkSEMICOLON then
        break
      when TkCOMMA then
        skip_tkspace false

        get_tk if TkNL === peek_tk
      end

      skip_tkspace false
    end
  end


  def parse_statements(container, single = NORMAL, current_method = nil,
                       comment = new_comment(''))
    raise 'no' unless RDoc::Comment === comment
    comment.force_encoding @encoding if @encoding

    nest = 1
    save_visibility = container.visibility

    non_comment_seen = true

    while tk = get_tk do
      keep_comment = false
      try_parse_comment = false

      non_comment_seen = true unless TkCOMMENT === tk

      case tk
      when TkNL then
        skip_tkspace
        tk = get_tk

        if TkCOMMENT === tk then
          if non_comment_seen then
            non_comment_seen = parse_comment container, tk, comment unless
              comment.empty?

            comment = ''
            comment.force_encoding @encoding if @encoding
          end

          while TkCOMMENT === tk do
            comment << tk.text << "\n"

            tk = get_tk

            if TkNL === tk then
              skip_tkspace false # leading spaces
              tk = get_tk
            end
          end

          comment = new_comment comment

          unless comment.empty? then
            look_for_directives_in container, comment

            if container.done_documenting then
              throw :eof if RDoc::TopLevel === container
              container.ongoing_visibility = save_visibility
            end
          end

          keep_comment = true
        else
          non_comment_seen = true
        end

        unget_tk tk
        keep_comment = true

      when TkCLASS then
        parse_class container, single, tk, comment

      when TkMODULE then
        parse_module container, single, tk, comment

      when TkDEF then
        parse_method container, single, tk, comment

      when TkCONSTANT then
        unless parse_constant container, tk, comment, current_method then
          try_parse_comment = true
        end

      when TkALIAS then
        parse_alias container, single, tk, comment unless current_method

      when TkYIELD then
        if current_method.nil? then
          warn "Warning: yield outside of method" if container.document_self
        else
          parse_yield container, single, tk, current_method
        end


      when TkUNTIL, TkWHILE then
        nest += 1
        skip_optional_do_after_expression

      when TkFOR then
        nest += 1
        skip_for_variable
        skip_optional_do_after_expression

      when TkCASE, TkDO, TkIF, TkUNLESS, TkBEGIN then
        nest += 1

      when TkSUPER then
        current_method.calls_super = true if current_method

      when TkRESCUE then
        parse_rescue

      when TkIDENTIFIER then
        if nest == 1 and current_method.nil? then
          keep_comment = parse_identifier container, single, tk, comment
        end

        case tk.name
        when "require" then
          parse_require container, comment
        when "include" then
          parse_extend_or_include RDoc::Include, container, comment
        when "extend" then
          parse_extend_or_include RDoc::Extend, container, comment
        end

      when TkEND then
        nest -= 1
        if nest == 0 then
          read_documentation_modifiers container, RDoc::CLASS_MODIFIERS
          container.ongoing_visibility = save_visibility

          parse_comment container, tk, comment unless comment.empty?

          return
        end
      else
        try_parse_comment = nest == 1
      end

      if try_parse_comment then
        non_comment_seen = parse_comment container, tk, comment unless
          comment.empty?

        keep_comment = false
      end

      unless keep_comment then
        comment = new_comment ''
        comment.force_encoding @encoding if @encoding
        container.params = nil
        container.block_params = nil
      end

      consume_trailing_spaces
    end

    container.params = nil
    container.block_params = nil
  end


  def parse_symbol_arg(no = nil)
    skip_tkspace_comment

    case tk = get_tk
    when TkLPAREN
      parse_symbol_arg_paren no
    else
      parse_symbol_arg_space no, tk
    end
  end


  def parse_symbol_arg_paren no # :nodoc:
    args = []

    loop do
      skip_tkspace_comment
      if tk1 = parse_symbol_in_arg
        args.push tk1
        break if no and args.size >= no
      end

      skip_tkspace_comment
      case tk2 = get_tk
      when TkRPAREN
        break
      when TkCOMMA
      else
        warn("unexpected token: '#{tk2.inspect}'") if $DEBUG_RDOC
        break
      end
    end

    args
  end


  def parse_symbol_arg_space no, tk # :nodoc:
    args = []

    unget_tk tk
    if tk = parse_symbol_in_arg
      args.push tk
      return args if no and args.size >= no
    end

    loop do
      skip_tkspace false

      tk1 = get_tk
      unless TkCOMMA === tk1 then
        unget_tk tk1
        break
      end

      skip_tkspace_comment
      if tk = parse_symbol_in_arg
        args.push tk
        break if no and args.size >= no
      end
    end

    args
  end


  def parse_symbol_in_arg
    case tk = get_tk
    when TkSYMBOL
      tk.text.sub(/^:/, '')
    when TkSTRING
      #nodyna <eval-2023> <EV COMPLEX (change-prone variables)>
      eval @read[-1]
    when TkDSTRING, TkIDENTIFIER then
      nil # ignore
    else
      warn("Expected symbol or string, got #{tk.inspect}") if $DEBUG_RDOC
      nil
    end
  end


  def parse_top_level_statements container
    comment = collect_first_comment

    look_for_directives_in container, comment

    throw :eof if container.done_documenting

    @markup = comment.format

    container.comment = comment if container.document_self unless comment.empty?

    parse_statements container, NORMAL, nil, comment
  end


  def parse_visibility(container, single, tk)
    vis_type, vis, singleton = get_visibility_information tk, single

    skip_tkspace_comment false

    case peek_tk
    when TkNL, TkUNLESS_MOD, TkIF_MOD, TkSEMICOLON then
      container.ongoing_visibility = vis
    else
      update_visibility container, vis_type, vis, singleton
    end
  end


  def parse_yield(context, single, tk, method)
    return if method.block_params

    get_tkread
    @scanner.continue = false
    method.block_params = parse_method_or_yield_parameters
  end


  def read_directive allowed
    tokens = []

    while tk = get_tk do
      tokens << tk

      case tk
      when TkNL, TkDEF then
        return
      when TkCOMMENT then
        return unless tk.text =~ /\s*:?([\w-]+):\s*(.*)/

        directive = $1.downcase

        return [directive, $2] if allowed.include? directive

        return
      end
    end
  ensure
    unless tokens.length == 1 and TkCOMMENT === tokens.first then
      tokens.reverse_each do |token|
        unget_tk token
      end
    end
  end


  def read_documentation_modifiers context, allowed
    directive, value = read_directive allowed

    return unless directive

    @preprocess.handle_directive '', directive, value, context do |dir, param|
      if %w[notnew not_new not-new].include? dir then
        context.dont_rename_initialize = true

        true
      end
    end
  end


  def record_location container # :nodoc:
    case container
    when RDoc::ClassModule then
      @top_level.add_to_classes_or_modules container
    end

    container.record_location @top_level
  end


  def remove_private_comments comment
    comment.remove_private
  end


  def scan
    reset

    catch :eof do
      begin
        parse_top_level_statements @top_level

      rescue StandardError => e
        bytes = ''

        20.times do @scanner.ungetc end
        count = 0
        60.times do |i|
          count = i
          byte = @scanner.getc
          break unless byte
          bytes << byte
        end
        count -= 20
        count.times do @scanner.ungetc end

        $stderr.puts <<-EOF


        EOF

        unless bytes.empty? then
          $stderr.puts
          $stderr.puts bytes.inspect
        end

        raise e
      end
    end

    @top_level
  end


  def skip_optional_do_after_expression
    skip_tkspace false
    tk = get_tk
    end_token = get_end_token tk

    b_nest = 0
    nest = 0
    @scanner.continue = false

    loop do
      case tk
      when TkSEMICOLON then
        break if b_nest.zero?
      when TkLPAREN, TkfLPAREN then
        nest += 1
      when TkBEGIN then
        b_nest += 1
      when TkEND then
        b_nest -= 1
      when TkDO
        break if nest.zero?
      when end_token then
        if end_token == TkRPAREN
          nest -= 1
          break if @scanner.lex_state == :EXPR_END and nest.zero?
        else
          break unless @scanner.continue
        end
      when nil then
        break
      end
      tk = get_tk
    end

    skip_tkspace false

    get_tk if TkDO === peek_tk
  end


  def skip_for_variable
    skip_tkspace false
    get_tk
    skip_tkspace false
    tk = get_tk
    unget_tk(tk) unless TkIN === tk
  end


  def skip_method container
    meth = RDoc::AnyMethod.new "", "anon"
    parse_method_parameters meth
    parse_statements container, false, meth
  end


  def skip_tkspace_comment(skip_nl = true)
    loop do
      skip_tkspace skip_nl
      return unless TkCOMMENT === peek_tk
      get_tk
    end
  end


  def update_visibility container, vis_type, vis, singleton # :nodoc:
    new_methods = []

    case vis_type
    when 'module_function' then
      args = parse_symbol_arg
      container.set_visibility_for args, :private, false

      container.methods_matching args do |m|
        s_m = m.dup
        record_location s_m
        s_m.singleton = true
        new_methods << s_m
      end
    when 'public_class_method', 'private_class_method' then
      args = parse_symbol_arg

      container.methods_matching args, true do |m|
        if m.parent != container then
          m = m.dup
          record_location m
          new_methods << m
        end

        m.visibility = vis
      end
    else
      args = parse_symbol_arg
      container.set_visibility_for args, vis, singleton
    end

    new_methods.each do |method|
      case method
      when RDoc::AnyMethod then
        container.add_method method
      when RDoc::Attr then
        container.add_attribute method
      end
      method.visibility = vis
    end
  end


  def warn message
    @options.warn make_message message
  end

end

