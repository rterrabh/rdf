
class RDoc::ClassModule < RDoc::Context


  MARSHAL_VERSION = 3 # :nodoc:


  attr_accessor :constant_aliases


  attr_accessor :comment_location

  attr_accessor :diagram # :nodoc:


  attr_accessor :is_alias_for


  def self.from_module class_type, mod
    klass = class_type.new mod.name

    mod.comment_location.each do |comment, location|
      klass.add_comment comment, location
    end

    klass.parent = mod.parent
    klass.section = mod.section
    klass.viewer = mod.viewer

    klass.attributes.concat mod.attributes
    klass.method_list.concat mod.method_list
    klass.aliases.concat mod.aliases
    klass.external_aliases.concat mod.external_aliases
    klass.constants.concat mod.constants
    klass.includes.concat mod.includes
    klass.extends.concat mod.extends

    klass.methods_hash.update mod.methods_hash
    klass.constants_hash.update mod.constants_hash

    klass.current_section = mod.current_section
    klass.in_files.concat mod.in_files
    klass.sections.concat mod.sections
    klass.unmatched_alias_lists = mod.unmatched_alias_lists
    klass.current_section = mod.current_section
    klass.visibility = mod.visibility

    klass.classes_hash.update mod.classes_hash
    klass.modules_hash.update mod.modules_hash
    klass.metadata.update mod.metadata

    klass.document_self = mod.received_nodoc ? nil : mod.document_self
    klass.document_children = mod.document_children
    klass.force_documentation = mod.force_documentation
    klass.done_documenting = mod.done_documenting


    (klass.attributes +
     klass.method_list +
     klass.aliases +
     klass.external_aliases +
     klass.constants +
     klass.includes +
     klass.extends +
     klass.classes +
     klass.modules).each do |obj|
      obj.parent = klass
      obj.full_name = nil
    end

    klass
  end


  def initialize(name, superclass = nil)
    @constant_aliases = []
    @diagram          = nil
    @is_alias_for     = nil
    @name             = name
    @superclass       = superclass
    @comment_location = [] # [[comment, location]]

    super()
  end


  def add_comment comment, location
    return unless document_self

    original = comment

    comment = case comment
              when RDoc::Comment then
                comment.normalize
              else
                normalize_comment comment
              end

    @comment_location.delete_if { |(_, l)| l == location }

    @comment_location << [comment, location]

    self.comment = original
  end

  def add_things my_things, other_things # :nodoc:
    other_things.each do |group, things|
      my_things[group].each { |thing| yield false, thing } if
        my_things.include? group

      things.each do |thing|
        yield true, thing
      end
    end
  end


  def ancestors
    includes.map { |i| i.module }.reverse
  end

  def aref_prefix # :nodoc:
    raise NotImplementedError, "missing aref_prefix for #{self.class}"
  end


  def aref
    "#{aref_prefix}-#{full_name}"
  end


  alias direct_ancestors ancestors


  def clear_comment
    @comment = ''
  end


  def comment= comment # :nodoc:
    comment = case comment
              when RDoc::Comment then
                comment.normalize
              else
                normalize_comment comment
              end

    comment = "#{@comment}\n---\n#{comment}" unless @comment.empty?

    super comment
  end


  def complete min_visibility
    update_aliases
    remove_nodoc_children
    update_includes
    remove_invisible min_visibility
  end


  def document_self_or_methods
    document_self || method_list.any?{ |m| m.document_self }
  end


  def documented?
    return true if @received_nodoc
    return false if @comment_location.empty?
    @comment_location.any? { |comment, _| not comment.empty? }
  end


  def each_ancestor # :yields: module
    return enum_for __method__ unless block_given?

    ancestors.each do |mod|
      next if String === mod
      next if self == mod
      yield mod
    end
  end


  def find_ancestor_local_symbol symbol
    each_ancestor do |m|
      res = m.find_local_symbol(symbol)
      return res if res
    end

    nil
  end


  def find_class_named name
    return self if full_name == name
    return self if @name == name

    @classes.values.find do |klass|
      next if klass == self
      klass.find_class_named name
    end
  end


  def full_name
    @full_name ||= if RDoc::ClassModule === parent then
                     "#{parent.full_name}::#{@name}"
                   else
                     @name
                   end
  end


  def marshal_dump # :nodoc:
    attrs = attributes.sort.map do |attr|
      next unless attr.display?
      [ attr.name, attr.rw,
        attr.visibility, attr.singleton, attr.file_name,
      ]
    end.compact

    method_types = methods_by_type.map do |type, visibilities|
      visibilities = visibilities.map do |visibility, methods|
        method_names = methods.map do |method|
          next unless method.display?
          [method.name, method.file_name]
        end.compact

        [visibility, method_names.uniq]
      end

      [type, visibilities]
    end

    [ MARSHAL_VERSION,
      @name,
      full_name,
      @superclass,
      parse(@comment_location),
      attrs,
      constants.select { |constant| constant.display? },
      includes.map do |incl|
        next unless incl.display?
        [incl.name, parse(incl.comment), incl.file_name]
      end.compact,
      method_types,
      extends.map do |ext|
        next unless ext.display?
        [ext.name, parse(ext.comment), ext.file_name]
      end.compact,
      @sections.values,
      @in_files.map do |tl|
        tl.relative_name
      end,
      parent.full_name,
      parent.class,
    ]
  end

  def marshal_load array # :nodoc:
    initialize_visibility
    initialize_methods_etc
    @current_section   = nil
    @document_self     = true
    @done_documenting  = false
    @parent            = nil
    @temporary_section = nil
    @visibility        = nil
    @classes           = {}
    @modules           = {}

    @name       = array[1]
    @full_name  = array[2]
    @superclass = array[3]
    @comment    = array[4]

    @comment_location = if RDoc::Markup::Document === @comment.parts.first then
                          @comment
                        else
                          RDoc::Markup::Document.new @comment
                        end

    array[5].each do |name, rw, visibility, singleton, file|
      singleton  ||= false
      visibility ||= :public

      attr = RDoc::Attr.new nil, name, rw, nil, singleton

      add_attribute attr
      attr.visibility = visibility
      attr.record_location RDoc::TopLevel.new file
    end

    array[6].each do |constant, comment, file|
      case constant
      when RDoc::Constant then
        add_constant constant
      else
        constant = add_constant RDoc::Constant.new(constant, nil, comment)
        constant.record_location RDoc::TopLevel.new file
      end
    end

    array[7].each do |name, comment, file|
      incl = add_include RDoc::Include.new(name, comment)
      incl.record_location RDoc::TopLevel.new file
    end

    array[8].each do |type, visibilities|
      visibilities.each do |visibility, methods|
        @visibility = visibility

        methods.each do |name, file|
          method = RDoc::AnyMethod.new nil, name
          method.singleton = true if type == 'class'
          method.record_location RDoc::TopLevel.new file
          add_method method
        end
      end
    end

    array[9].each do |name, comment, file|
      ext = add_extend RDoc::Extend.new(name, comment)
      ext.record_location RDoc::TopLevel.new file
    end if array[9] # Support Marshal version 1

    sections = (array[10] || []).map do |section|
      [section.title, section]
    end

    @sections = Hash[*sections.flatten]
    @current_section = add_section nil

    @in_files = []

    (array[11] || []).each do |filename|
      record_location RDoc::TopLevel.new filename
    end

    @parent_name  = array[12]
    @parent_class = array[13]
  end


  def merge class_module
    @parent      = class_module.parent
    @parent_name = class_module.parent_name

    other_document = parse class_module.comment_location

    if other_document then
      document = parse @comment_location

      document = document.merge other_document

      @comment = @comment_location = document
    end

    cm = class_module
    other_files = cm.in_files

    merge_collections attributes, cm.attributes, other_files do |add, attr|
      if add then
        add_attribute attr
      else
        @attributes.delete attr
        @methods_hash.delete attr.pretty_name
      end
    end

    merge_collections constants, cm.constants, other_files do |add, const|
      if add then
        add_constant const
      else
        @constants.delete const
        @constants_hash.delete const.name
      end
    end

    merge_collections includes, cm.includes, other_files do |add, incl|
      if add then
        add_include incl
      else
        @includes.delete incl
      end
    end

    @includes.uniq! # clean up

    merge_collections extends, cm.extends, other_files do |add, ext|
      if add then
        add_extend ext
      else
        @extends.delete ext
      end
    end

    @extends.uniq! # clean up

    merge_collections method_list, cm.method_list, other_files do |add, meth|
      if add then
        add_method meth
      else
        @method_list.delete meth
        @methods_hash.delete meth.pretty_name
      end
    end

    merge_sections cm

    self
  end


  def merge_collections mine, other, other_files, &block # :nodoc:
    my_things    = mine. group_by { |thing| thing.file }
    other_things = other.group_by { |thing| thing.file }

    remove_things my_things, other_files,  &block
    add_things    my_things, other_things, &block
  end


  def merge_sections cm # :nodoc:
    my_sections    =    sections.group_by { |section| section.title }
    other_sections = cm.sections.group_by { |section| section.title }

    other_files = cm.in_files

    remove_things my_sections, other_files do |_, section|
      @sections.delete section.title
    end

    other_sections.each do |group, sections|
      if my_sections.include? group
        my_sections[group].each do |my_section|
          other_section = cm.sections_hash[group]

          my_comments    = my_section.comments
          other_comments = other_section.comments

          other_files = other_section.in_files

          merge_collections my_comments, other_comments, other_files do |add, comment|
            if add then
              my_section.add_comment comment
            else
              my_section.remove_comment comment
            end
          end
        end
      else
        sections.each do |section|
          add_section group, section.comments
        end
      end
    end
  end


  def module?
    false
  end


  def name= new_name
    @name = new_name
  end


  def parse comment_location
    case comment_location
    when String then
      super
    when Array then
      docs = comment_location.map do |comment, location|
        doc = super comment
        doc.file = location
        doc
      end

      RDoc::Markup::Document.new(*docs)
    when RDoc::Comment then
      doc = super comment_location.text, comment_location.format
      doc.file = comment_location.location
      doc
    when RDoc::Markup::Document then
      return comment_location
    else
      raise ArgumentError, "unknown comment class #{comment_location.class}"
    end
  end


  def path
    http_url @store.rdoc.generator.class_dir
  end


  def name_for_path
    is_alias_for ? is_alias_for.full_name : full_name
  end


  def non_aliases
    @non_aliases ||= classes_and_modules.reject { |cm| cm.is_alias_for }
  end


  def remove_nodoc_children
    prefix = self.full_name + '::'

    modules_hash.each_key do |name|
      full_name = prefix + name
      modules_hash.delete name unless @store.modules_hash[full_name]
    end

    classes_hash.each_key do |name|
      full_name = prefix + name
      classes_hash.delete name unless @store.classes_hash[full_name]
    end
  end

  def remove_things my_things, other_files # :nodoc:
    my_things.delete_if do |file, things|
      next false unless other_files.include? file

      things.each do |thing|
        yield false, thing
      end

      true
    end
  end


  def search_record
    [
      name,
      full_name,
      full_name,
      '',
      path,
      '',
      snippet(@comment_location),
    ]
  end


  def store= store
    super

    @attributes .each do |attr|  attr.store  = store end
    @constants  .each do |const| const.store = store end
    @includes   .each do |incl|  incl.store  = store end
    @extends    .each do |ext|   ext.store   = store end
    @method_list.each do |meth|  meth.store  = store end
  end


  def superclass
    @store.find_class_named(@superclass) || @superclass
  end


  def superclass=(superclass)
    raise NoMethodError, "#{full_name} is a module" if module?
    @superclass = superclass
  end

  def to_s # :nodoc:
    if is_alias_for then
      "#{self.class.name} #{self.full_name} -> #{is_alias_for}"
    else
      super
    end
  end


  def type
    module? ? 'module' : 'class'
  end


  def update_aliases
    constants.each do |const|
      next unless cm = const.is_alias_for
      cm_alias = cm.dup
      cm_alias.name = const.name

      unless RDoc::TopLevel === cm_alias.parent then
        cm_alias.parent = self
        cm_alias.full_name = nil # force update for new parent
      end

      cm_alias.aliases.clear
      cm_alias.is_alias_for = cm

      if cm.module? then
        @store.modules_hash[cm_alias.full_name] = cm_alias
        modules_hash[const.name] = cm_alias
      else
        @store.classes_hash[cm_alias.full_name] = cm_alias
        classes_hash[const.name] = cm_alias
      end

      cm.aliases << cm_alias
    end
  end


  def update_includes
    includes.reject! do |include|
      mod = include.module
      !(String === mod) && @store.modules_hash[mod.full_name].nil?
    end

    includes.uniq!
  end


  def update_extends
    extends.reject! do |ext|
      mod = ext.module

      !(String === mod) && @store.modules_hash[mod.full_name].nil?
    end

    extends.uniq!
  end

end

