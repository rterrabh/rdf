require 'cgi'


class RDoc::Context < RDoc::CodeObject

  include Comparable


  TYPES = %w[class instance]


  TOMDOC_TITLES = [nil, 'Public', 'Internal', 'Deprecated'] # :nodoc:
  TOMDOC_TITLES_SORT = TOMDOC_TITLES.sort_by { |title| title.to_s } # :nodoc:


  attr_reader :aliases


  attr_reader :attributes


  attr_accessor :block_params


  attr_reader :constants


  attr_writer :current_section


  attr_reader :in_files


  attr_reader :includes


  attr_reader :extends


  attr_reader :method_list


  attr_reader :name


  attr_reader :requires


  attr_accessor :temporary_section


  attr_accessor :unmatched_alias_lists


  attr_reader :external_aliases


  attr_accessor :visibility


  attr_reader :methods_hash


  attr_accessor :params


  attr_reader :constants_hash


  def initialize
    super

    @in_files = []

    @name    ||= "unknown"
    @parent  = nil
    @visibility = :public

    @current_section = Section.new self, nil, nil
    @sections = { nil => @current_section }
    @temporary_section = nil

    @classes = {}
    @modules = {}

    initialize_methods_etc
  end


  def initialize_methods_etc
    @method_list = []
    @attributes  = []
    @aliases     = []
    @requires    = []
    @includes    = []
    @extends     = []
    @constants   = []
    @external_aliases = []

    @unmatched_alias_lists = {}

    @methods_hash   = {}
    @constants_hash = {}

    @params = nil

    @store ||= nil
  end


  def <=>(other)
    return nil unless RDoc::CodeObject === other

    full_name <=> other.full_name
  end


  def add klass, name, comment
    if RDoc::Extend == klass then
      ext = RDoc::Extend.new name, comment
      add_extend ext
    elsif RDoc::Include == klass then
      incl = RDoc::Include.new name, comment
      add_include incl
    else
      raise NotImplementedError, "adding a #{klass} is not implemented"
    end
  end


  def add_alias an_alias
    return an_alias unless @document_self

    method_attr = find_method(an_alias.old_name, an_alias.singleton) ||
                  find_attribute(an_alias.old_name, an_alias.singleton)

    if method_attr then
      method_attr.add_alias an_alias, self
    else
      add_to @external_aliases, an_alias
      unmatched_alias_list =
        @unmatched_alias_lists[an_alias.pretty_old_name] ||= []
      unmatched_alias_list.push an_alias
    end

    an_alias
  end


  def add_attribute attribute
    return attribute unless @document_self

    register = false

    key = nil

    if attribute.rw.index 'R' then
      key = attribute.pretty_name
      known = @methods_hash[key]

      if known then
        known.comment = attribute.comment if known.comment.empty?
      elsif registered = @methods_hash[attribute.pretty_name << '='] and
            RDoc::Attr === registered then
        registered.rw = 'RW'
      else
        @methods_hash[key] = attribute
        register = true
      end
    end

    if attribute.rw.index 'W' then
      key = attribute.pretty_name << '='
      known = @methods_hash[key]

      if known then
        known.comment = attribute.comment if known.comment.empty?
      elsif registered = @methods_hash[attribute.pretty_name] and
            RDoc::Attr === registered then
        registered.rw = 'RW'
      else
        @methods_hash[key] = attribute
        register = true
      end
    end

    if register then
      attribute.visibility = @visibility
      add_to @attributes, attribute
      resolve_aliases attribute
    end

    attribute
  end


  def add_class class_type, given_name, superclass = '::Object'

    if given_name =~ /^:+(\w+)$/ then
      full_name = $1
      enclosing = top_level
      name = full_name.split(/:+/).last
    else
      full_name = child_name given_name

      if full_name =~ /^(.+)::(\w+)$/ then
        name = $2
        ename = $1
        enclosing = @store.classes_hash[ename] || @store.modules_hash[ename]
        unless enclosing then
          enclosing = @store.classes_hash[given_name] ||
                      @store.modules_hash[given_name]
          return enclosing if enclosing
          names = ename.split('::')
          enclosing = self
          names.each do |n|
            enclosing = enclosing.classes_hash[n] ||
                        enclosing.modules_hash[n] ||
                        enclosing.add_module(RDoc::NormalModule, n)
          end
        end
      else
        name = full_name
        enclosing = self
      end
    end

    if full_name == 'BasicObject' then
      superclass = nil
    elsif full_name == 'Object' then
      superclass = defined?(::BasicObject) ? '::BasicObject' : nil
    end

    if superclass then
      if superclass =~ /^:+/ then
        superclass = $' #'
      else
        if superclass =~ /^(\w+):+(.+)$/ then
          suffix = $2
          mod = find_module_named($1)
          superclass = mod.full_name + '::' + suffix if mod
        else
          mod = find_module_named(superclass)
          superclass = mod.full_name if mod
        end
      end

      mod = @store.modules_hash.delete superclass

      upgrade_to_class mod, RDoc::NormalClass, mod.parent if mod

      superclass = nil if superclass == full_name
    end

    klass = @store.classes_hash[full_name]

    if klass then
      enclosing.classes_hash[name] = klass

      if superclass then
        existing = klass.superclass
        existing = existing.full_name unless existing.is_a?(String) if existing
        if existing.nil? ||
           (existing == 'Object' && superclass != 'Object') then
          klass.superclass = superclass
        end
      end
    else
      mod = @store.modules_hash.delete full_name

      if mod then
        klass = upgrade_to_class mod, RDoc::NormalClass, enclosing

        klass.superclass = superclass unless superclass.nil?
      else
        klass = class_type.new name, superclass

        enclosing.add_class_or_module(klass, enclosing.classes_hash,
                                      @store.classes_hash)
      end
    end

    klass.parent = self

    klass
  end


  def add_class_or_module mod, self_hash, all_hash
    mod.section = current_section # TODO declaring context? something is
    mod.parent = self
    mod.store = @store

    unless @done_documenting then
      self_hash[mod.name] = mod
      all_hash[mod.full_name] = mod
    end

    mod
  end


  def add_constant constant
    return constant unless @document_self

    known = @constants_hash[constant.name]

    if known then
      known.comment = constant.comment if known.comment.empty?

      known.value = constant.value if
        known.value.nil? or known.value.strip.empty?

      known.is_alias_for ||= constant.is_alias_for
    else
      @constants_hash[constant.name] = constant
      add_to @constants, constant
    end

    constant
  end


  def add_include include
    add_to @includes, include

    include
  end


  def add_extend ext
    add_to @extends, ext

    ext
  end


  def add_method method
    return method unless @document_self

    key = method.pretty_name
    known = @methods_hash[key]

    if known then
      if @store then # otherwise we are loading
        known.comment = method.comment if known.comment.empty?
        previously = ", previously in #{known.file}" unless
          method.file == known.file
        @store.rdoc.options.warn \
          "Duplicate method #{known.full_name} in #{method.file}#{previously}"
      end
    else
      @methods_hash[key] = method
      method.visibility = @visibility
      add_to @method_list, method
      resolve_aliases method
    end

    method
  end


  def add_module(class_type, name)
    mod = @classes[name] || @modules[name]
    return mod if mod

    full_name = child_name name
    mod = @store.modules_hash[full_name] || class_type.new(name)

    add_class_or_module mod, @modules, @store.modules_hash
  end


  def add_module_alias from, name, file
    return from if @done_documenting

    to_name = child_name name

    return from if @store.find_class_or_module to_name

    to = from.dup
    to.name = name
    to.full_name = nil

    if to.module? then
      @store.modules_hash[to_name] = to
      @modules[name] = to
    else
      @store.classes_hash[to_name] = to
      @classes[name] = to
    end

    const = RDoc::Constant.new name, nil, to.comment
    const.record_location file
    const.is_alias_for = from
    add_constant const

    to
  end


  def add_require(require)
    return require unless @document_self

    if RDoc::TopLevel === self then
      add_to @requires, require
    else
      parent.add_require require
    end
  end


  def add_section title, comment = nil
    if section = @sections[title] then
      section.add_comment comment if comment
    else
      section = Section.new self, title, comment
      @sections[title] = section
    end

    section
  end


  def add_to array, thing
    array << thing if @document_self

    thing.parent  = self
    thing.store   = @store if @store
    thing.section = current_section
  end


  def any_content(includes = true)
    @any_content ||= !(
      @comment.empty? &&
      @method_list.empty? &&
      @attributes.empty? &&
      @aliases.empty? &&
      @external_aliases.empty? &&
      @requires.empty? &&
      @constants.empty?
    )
    @any_content || (includes && !(@includes + @extends).empty? )
  end


  def child_name name
    if name =~ /^:+/
      $'  #'
    elsif RDoc::TopLevel === self then
      name
    else
      "#{self.full_name}::#{name}"
    end
  end


  def class_attributes
    @class_attributes ||= attributes.select { |a| a.singleton }
  end


  def class_method_list
    @class_method_list ||= method_list.select { |a| a.singleton }
  end


  def classes
    @classes.values
  end


  def classes_and_modules
    classes + modules
  end


  def classes_hash
    @classes
  end


  def current_section
    if section = @temporary_section then
      @temporary_section = nil
    else
      section = @current_section
    end

    section
  end


  def defined_in?(file)
    @in_files.include?(file)
  end

  def display(method_attr) # :nodoc:
    if method_attr.is_a? RDoc::Attr
      "#{method_attr.definition} #{method_attr.pretty_name}"
    else
      "method #{method_attr.pretty_name}"
    end
  end


  def each_ancestor # :nodoc:
  end


  def each_attribute # :yields: attribute
    @attributes.each { |a| yield a }
  end


  def each_classmodule(&block) # :yields: module
    classes_and_modules.sort.each(&block)
  end


  def each_constant # :yields: constant
    @constants.each {|c| yield c}
  end


  def each_include # :yields: include
    @includes.each do |i| yield i end
  end


  def each_extend # :yields: extend
    @extends.each do |e| yield e end
  end


  def each_method # :yields: method
    return enum_for __method__ unless block_given?

    @method_list.sort.each { |m| yield m }
  end


  def each_section # :yields: section, constants, attributes
    return enum_for __method__ unless block_given?

    constants  = @constants.group_by  do |constant|  constant.section end
    attributes = @attributes.group_by do |attribute| attribute.section end

    constants.default  = []
    attributes.default = []

    sort_sections.each do |section|
      yield section, constants[section].sort, attributes[section].sort
    end
  end


  def find_attribute(name, singleton)
    name = $1 if name =~ /^(.*)=$/
    @attributes.find { |a| a.name == name && a.singleton == singleton }
  end


  def find_attribute_named(name)
    case name
    when /\A#/ then
      find_attribute name[1..-1], false
    when /\A::/ then
      find_attribute name[2..-1], true
    else
      @attributes.find { |a| a.name == name }
    end
  end


  def find_class_method_named(name)
    @method_list.find { |meth| meth.singleton && meth.name == name }
  end


  def find_constant_named(name)
    @constants.find {|m| m.name == name}
  end


  def find_enclosing_module_named(name)
    parent && parent.find_module_named(name)
  end


  def find_external_alias(name, singleton)
    @external_aliases.find { |m| m.name == name && m.singleton == singleton }
  end


  def find_external_alias_named(name)
    case name
    when /\A#/ then
      find_external_alias name[1..-1], false
    when /\A::/ then
      find_external_alias name[2..-1], true
    else
      @external_aliases.find { |a| a.name == name }
    end
  end


  def find_file_named name
    @store.find_file_named name
  end


  def find_instance_method_named(name)
    @method_list.find { |meth| !meth.singleton && meth.name == name }
  end


  def find_local_symbol(symbol)
    find_method_named(symbol) or
    find_constant_named(symbol) or
    find_attribute_named(symbol) or
    find_external_alias_named(symbol) or
    find_module_named(symbol) or
    find_file_named(symbol)
  end


  def find_method(name, singleton)
    @method_list.find { |m| m.name == name && m.singleton == singleton }
  end


  def find_method_named(name)
    case name
    when /\A#/ then
      find_method name[1..-1], false
    when /\A::/ then
      find_method name[2..-1], true
    else
      @method_list.find { |meth| meth.name == name }
    end
  end


  def find_module_named(name)
    res = @modules[name] || @classes[name]
    return res if res
    return self if self.name == name
    find_enclosing_module_named name
  end


  def find_symbol(symbol)
    find_symbol_module(symbol) || find_local_symbol(symbol)
  end


  def find_symbol_module(symbol)
    result = nil

    case symbol
    when /^::/ then
      result = @store.find_class_or_module symbol
    when /^(\w+):+(.+)$/
      suffix = $2
      top = $1
      searched = self
      while searched do
        mod = searched.find_module_named(top)
        break unless mod
        result = @store.find_class_or_module "#{mod.full_name}::#{suffix}"
        break if result || searched.is_a?(RDoc::TopLevel)
        searched = searched.parent
      end
    else
      searched = self
      while searched do
        result = searched.find_module_named(symbol)
        break if result || searched.is_a?(RDoc::TopLevel)
        searched = searched.parent
      end
    end

    result
  end


  def full_name
    '(unknown)'
  end


  def fully_documented?
    documented? and
      attributes.all? { |a| a.documented? } and
      method_list.all? { |m| m.documented? } and
      constants.all? { |c| c.documented? }
  end


  def http_url(prefix)
    path = name_for_path
    path = path.gsub(/<<\s*(\w*)/, 'from-\1') if path =~ /<</
    path = [prefix] + path.split('::')

    File.join(*path.compact) + '.html'
  end


  def instance_attributes
    @instance_attributes ||= attributes.reject { |a| a.singleton }
  end


  def instance_method_list
    @instance_method_list ||= method_list.reject { |a| a.singleton }
  end


  def methods_by_type section = nil
    methods = {}

    TYPES.each do |type|
      visibilities = {}
      RDoc::VISIBILITIES.each do |vis|
        visibilities[vis] = []
      end

      methods[type] = visibilities
    end

    each_method do |method|
      next if section and not method.section == section
      methods[method.type][method.visibility] << method
    end

    methods
  end


  def methods_matching(methods, singleton = false, &block)
    (@method_list + @attributes).each do |m|
      yield m if methods.include?(m.name) and m.singleton == singleton
    end

    each_ancestor do |parent|
      parent.methods_matching(methods, singleton, &block)
    end
  end


  def modules
    @modules.values
  end


  def modules_hash
    @modules
  end


  def name_for_path
    full_name
  end


  def ongoing_visibility=(visibility)
    @visibility = visibility
  end


  def record_location(top_level)
    @in_files << top_level unless @in_files.include?(top_level)
  end


  def remove_from_documentation?
    @remove_from_documentation ||=
      @received_nodoc &&
      !any_content(false) &&
      @includes.all? { |i| !i.module.is_a?(String) && i.module.remove_from_documentation? } &&
      classes_and_modules.all? { |cm| cm.remove_from_documentation? }
  end


  def remove_invisible min_visibility
    return if [:private, :nodoc].include? min_visibility
    remove_invisible_in @method_list, min_visibility
    remove_invisible_in @attributes, min_visibility
  end


  def remove_invisible_in array, min_visibility # :nodoc:
    if min_visibility == :public then
      array.reject! { |e|
        e.visibility != :public and not e.force_documentation
      }
    else
      array.reject! { |e|
        e.visibility == :private and not e.force_documentation
      }
    end
  end


  def resolve_aliases added
    key = added.pretty_name
    unmatched_alias_list = @unmatched_alias_lists[key]
    return unless unmatched_alias_list
    unmatched_alias_list.each do |unmatched_alias|
      added.add_alias unmatched_alias, self
      @external_aliases.delete unmatched_alias
    end
    @unmatched_alias_lists.delete key
  end


  def section_contents
    used_sections = {}

    each_method do |method|
      next unless method.display?

      used_sections[method.section] = true
    end

    sections = sort_sections.select do |section|
      used_sections[section]
    end

    return [] if
      sections.length == 1 and not sections.first.title

    sections
  end


  def sections
    @sections.values
  end

  def sections_hash # :nodoc:
    @sections
  end


  def set_current_section title, comment
    @current_section = add_section title, comment
  end


  def set_visibility_for(methods, visibility, singleton = false)
    methods_matching methods, singleton do |m|
      m.visibility = visibility
    end
  end


  def sort_sections
    titles = @sections.map { |title, _| title }

    if titles.length > 1 and
       TOMDOC_TITLES_SORT ==
         (titles | TOMDOC_TITLES).sort_by { |title| title.to_s } then
      @sections.values_at(*TOMDOC_TITLES).compact
    else
      @sections.sort_by { |title, _|
        title.to_s
      }.map { |_, section|
        section
      }
    end
  end

  def to_s # :nodoc:
    "#{self.class.name} #{self.full_name}"
  end


  def top_level
    return @top_level if defined? @top_level
    @top_level = self
    @top_level = @top_level.parent until RDoc::TopLevel === @top_level
    @top_level
  end


  def upgrade_to_class mod, class_type, enclosing
    enclosing.modules_hash.delete mod.name

    klass = RDoc::ClassModule.from_module class_type, mod
    klass.store = @store

    @store.classes_hash[mod.full_name] = klass
    enclosing.classes_hash[mod.name]   = klass

    klass
  end

  autoload :Section, 'rdoc/context/section'

end

