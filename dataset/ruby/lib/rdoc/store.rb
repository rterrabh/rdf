require 'fileutils'


class RDoc::Store


  class Error < RDoc::Error
  end


  class MissingFileError < Error


    attr_reader :store


    attr_reader :file


    attr_reader :name


    def initialize store, file, name
      @store = store
      @file  = file
      @name  = name
    end

    def message # :nodoc:
      "store at #{@store.path} missing file #{@file} for #{@name}"
    end

  end


  attr_reader :c_enclosure_classes # :nodoc:

  attr_reader :c_enclosure_names # :nodoc:


  attr_reader :c_class_variables


  attr_reader :c_singleton_class_variables


  attr_accessor :dry_run


  attr_accessor :path


  attr_accessor :rdoc


  attr_accessor :type


  attr_reader :cache


  attr_accessor :encoding


  def initialize path = nil, type = nil
    @dry_run  = false
    @encoding = nil
    @path     = path
    @rdoc     = nil
    @type     = type

    @cache = {
      :ancestors                   => {},
      :attributes                  => {},
      :class_methods               => {},
      :c_class_variables           => {},
      :c_singleton_class_variables => {},
      :encoding                    => @encoding,
      :instance_methods            => {},
      :main                        => nil,
      :modules                     => [],
      :pages                       => [],
      :title                       => nil,
    }

    @classes_hash = {}
    @modules_hash = {}
    @files_hash   = {}

    @c_enclosure_classes = {}
    @c_enclosure_names   = {}

    @c_class_variables           = {}
    @c_singleton_class_variables = {}

    @unique_classes = nil
    @unique_modules = nil
  end


  def add_c_enclosure variable, namespace
    @c_enclosure_classes[variable] = namespace
  end


  def add_c_variables c_parser
    filename = c_parser.top_level.relative_name

    @c_class_variables[filename] = make_variable_map c_parser.classes

    @c_singleton_class_variables[filename] = c_parser.singleton_classes
  end


  def add_file absolute_name, relative_name = absolute_name
    unless top_level = @files_hash[relative_name] then
      top_level = RDoc::TopLevel.new absolute_name, relative_name
      top_level.store = self
      @files_hash[relative_name] = top_level
    end

    top_level
  end


  def all_classes
    @classes_hash.values
  end


  def all_classes_and_modules
    @classes_hash.values + @modules_hash.values
  end


  def all_files
    @files_hash.values
  end


  def all_modules
    modules_hash.values
  end


  def ancestors
    @cache[:ancestors]
  end


  def attributes
    @cache[:attributes]
  end


  def cache_path
    File.join @path, 'cache.ri'
  end


  def class_file klass_name
    name = klass_name.split('::').last
    File.join class_path(klass_name), "cdesc-#{name}.ri"
  end


  def class_methods
    @cache[:class_methods]
  end


  def class_path klass_name
    File.join @path, *klass_name.split('::')
  end


  def classes_hash
    @classes_hash
  end


  def clean_cache_collection collection # :nodoc:
    collection.each do |name, item|
      if item.empty? then
        collection.delete name
      else
        item.uniq!
        item.sort!
      end
    end
  end


  def complete min_visibility
    fix_basic_object_inheritance

    all_classes_and_modules.each { |cm| cm.ancestors }

    unless min_visibility == :nodoc then
      remove_nodoc @classes_hash
      remove_nodoc @modules_hash
    end

    @unique_classes = find_unique @classes_hash
    @unique_modules = find_unique @modules_hash

    unique_classes_and_modules.each do |cm|
      cm.complete min_visibility
    end

    @files_hash.each_key do |file_name|
      tl = @files_hash[file_name]

      unless tl.text? then
        tl.modules_hash.clear
        tl.classes_hash.clear

        tl.classes_or_modules.each do |cm|
          name = cm.full_name
          if cm.type == 'class' then
            tl.classes_hash[name] = cm if @classes_hash[name]
          else
            tl.modules_hash[name] = cm if @modules_hash[name]
          end
        end
      end
    end
  end


  def files_hash
    @files_hash
  end


  def find_c_enclosure variable
    @c_enclosure_classes.fetch variable do
      break unless name = @c_enclosure_names[variable]

      mod = find_class_or_module name

      unless mod then
        loaded_mod = load_class_data name

        file = loaded_mod.in_files.first

        return unless file # legacy data source

        file.store = self

        mod = file.add_module RDoc::NormalModule, name
      end

      @c_enclosure_classes[variable] = mod
    end
  end


  def find_class_named name
    @classes_hash[name]
  end


  def find_class_named_from name, from
    from = find_class_named from unless RDoc::Context === from

    until RDoc::TopLevel === from do
      return nil unless from

      klass = from.find_class_named name
      return klass if klass

      from = from.parent
    end

    find_class_named name
  end


  def find_class_or_module name
    name = $' if name =~ /^::/
    @classes_hash[name] || @modules_hash[name]
  end


  def find_file_named name
    @files_hash[name]
  end


  def find_module_named name
    @modules_hash[name]
  end


  def find_text_page file_name
    @files_hash.each_value.find do |file|
      file.text? and file.full_name == file_name
    end
  end


  def find_unique all_hash
    unique = []

    all_hash.each_pair do |full_name, cm|
      unique << cm if full_name == cm.full_name
    end

    unique
  end


  def fix_basic_object_inheritance
    basic = classes_hash['BasicObject']
    return unless basic
    if RUBY_VERSION >= '1.9'
      basic.superclass = nil
    elsif basic.in_files.any? { |f| File.basename(f.full_name) == 'object.c' }
      basic.superclass = nil
    end
  end


  def friendly_path
    case type
    when :gem    then
      parent = File.expand_path '..', @path
      "gem #{File.basename parent}"
    when :home   then '~/.rdoc'
    when :site   then 'ruby site'
    when :system then 'ruby core'
    else @path
    end
  end

  def inspect # :nodoc:
    "#<%s:0x%x %s %p>" % [self.class, object_id, @path, module_names.sort]
  end


  def instance_methods
    @cache[:instance_methods]
  end


  def load_all
    load_cache

    module_names.each do |module_name|
      mod = find_class_or_module(module_name) || load_class(module_name)

      loaded_methods = mod.method_list.map do |method|
        load_method module_name, method.full_name
      end

      mod.method_list.replace loaded_methods

      loaded_attributes = mod.attributes.map do |attribute|
        load_method module_name, attribute.full_name
      end

      mod.attributes.replace loaded_attributes
    end

    all_classes_and_modules.each do |mod|
      descendent_re = /^#{mod.full_name}::[^:]+$/

      module_names.each do |name|
        next unless name =~ descendent_re

        descendent = find_class_or_module name

        case descendent
        when RDoc::NormalClass then
          mod.classes_hash[name] = descendent
        when RDoc::NormalModule then
          mod.modules_hash[name] = descendent
        end
      end
    end

    @cache[:pages].each do |page_name|
      page = load_page page_name
      @files_hash[page_name] = page
    end
  end


  def load_cache

    open cache_path, 'rb' do |io|
      @cache = Marshal.load io.read
    end

    load_enc = @cache[:encoding]


    @encoding = load_enc unless @encoding

    @cache[:pages]                       ||= []
    @cache[:main]                        ||= nil
    @cache[:c_class_variables]           ||= {}
    @cache[:c_singleton_class_variables] ||= {}

    @cache[:c_class_variables].each do |_, map|
      map.each do |variable, name|
        @c_enclosure_names[variable] = name
      end
    end

    @cache
  rescue Errno::ENOENT
  end


  def load_class klass_name
    obj = load_class_data klass_name

    obj.store = self

    case obj
    when RDoc::NormalClass then
      @classes_hash[klass_name] = obj
    when RDoc::NormalModule then
      @modules_hash[klass_name] = obj
    end
  end


  def load_class_data klass_name
    file = class_file klass_name

    open file, 'rb' do |io|
      Marshal.load io.read
    end
  rescue Errno::ENOENT => e
    error = MissingFileError.new(self, file, klass_name)
    error.set_backtrace e.backtrace
    raise error
  end


  def load_method klass_name, method_name
    file = method_file klass_name, method_name

    open file, 'rb' do |io|
      obj = Marshal.load io.read
      obj.store = self
      obj.parent =
        find_class_or_module(klass_name) || load_class(klass_name) unless
          obj.parent
      obj
    end
  rescue Errno::ENOENT => e
    error = MissingFileError.new(self, file, klass_name + method_name)
    error.set_backtrace e.backtrace
    raise error
  end


  def load_page page_name
    file = page_file page_name

    open file, 'rb' do |io|
      obj = Marshal.load io.read
      obj.store = self
      obj
    end
  rescue Errno::ENOENT => e
    error = MissingFileError.new(self, file, page_name)
    error.set_backtrace e.backtrace
    raise error
  end


  def main
    @cache[:main]
  end


  def main= page
    @cache[:main] = page
  end


  def make_variable_map variables
    map = {}

    variables.each { |variable, class_module|
      map[variable] = class_module.full_name
    }

    map
  end


  def method_file klass_name, method_name
    method_name = method_name.split('::').last
    method_name =~ /#(.*)/
    method_type = $1 ? 'i' : 'c'
    method_name = $1 if $1

    method_name = if ''.respond_to? :ord then
                    method_name.gsub(/\W/) { "%%%02x" % $&[0].ord }
                  else
                    method_name.gsub(/\W/) { "%%%02x" % $&[0] }
                  end

    File.join class_path(klass_name), "#{method_name}-#{method_type}.ri"
  end


  def module_names
    @cache[:modules]
  end


  def modules_hash
    @modules_hash
  end


  def page name
    @files_hash.each_value.find do |file|
      file.text? and file.page_name == name
    end
  end


  def page_file page_name
    file_name = File.basename(page_name).gsub('.', '_')

    File.join @path, File.dirname(page_name), "page-#{file_name}.ri"
  end


  def remove_nodoc all_hash
    all_hash.keys.each do |name|
      context = all_hash[name]
      all_hash.delete(name) if context.remove_from_documentation?
    end
  end


  def save
    load_cache

    all_classes_and_modules.each do |klass|
      save_class klass

      klass.each_method do |method|
        save_method klass, method
      end

      klass.each_attribute do |attribute|
        save_method klass, attribute
      end
    end

    all_files.each do |file|
      save_page file
    end

    save_cache
  end


  def save_cache
    clean_cache_collection @cache[:ancestors]
    clean_cache_collection @cache[:attributes]
    clean_cache_collection @cache[:class_methods]
    clean_cache_collection @cache[:instance_methods]

    @cache[:modules].uniq!
    @cache[:modules].sort!

    @cache[:pages].uniq!
    @cache[:pages].sort!

    @cache[:encoding] = @encoding # this gets set twice due to assert_cache

    @cache[:c_class_variables].merge!           @c_class_variables
    @cache[:c_singleton_class_variables].merge! @c_singleton_class_variables

    return if @dry_run

    marshal = Marshal.dump @cache

    open cache_path, 'wb' do |io|
      io.write marshal
    end
  end


  def save_class klass
    full_name = klass.full_name

    FileUtils.mkdir_p class_path(full_name) unless @dry_run

    @cache[:modules] << full_name

    path = class_file full_name

    begin
      disk_klass = load_class full_name

      klass = disk_klass.merge klass
    rescue MissingFileError
    end

    ancestors = klass.direct_ancestors.compact.map do |ancestor|
      String === ancestor ? ancestor : ancestor.full_name
    end

    @cache[:ancestors][full_name] ||= []
    @cache[:ancestors][full_name].concat ancestors

    attribute_definitions = klass.attributes.map do |attribute|
      "#{attribute.definition} #{attribute.name}"
    end

    unless attribute_definitions.empty? then
      @cache[:attributes][full_name] ||= []
      @cache[:attributes][full_name].concat attribute_definitions
    end

    to_delete = []

    unless klass.method_list.empty? then
      @cache[:class_methods][full_name]    ||= []
      @cache[:instance_methods][full_name] ||= []

      class_methods, instance_methods =
        klass.method_list.partition { |meth| meth.singleton }

      class_methods    = class_methods.   map { |method| method.name }
      instance_methods = instance_methods.map { |method| method.name }
      attribute_names  = klass.attributes.map { |attr|   attr.name }

      old = @cache[:class_methods][full_name] - class_methods
      to_delete.concat old.map { |method|
        method_file full_name, "#{full_name}::#{method}"
      }

      old = @cache[:instance_methods][full_name] -
        instance_methods - attribute_names
      to_delete.concat old.map { |method|
        method_file full_name, "#{full_name}##{method}"
      }

      @cache[:class_methods][full_name]    = class_methods
      @cache[:instance_methods][full_name] = instance_methods
    end

    return if @dry_run

    FileUtils.rm_f to_delete

    marshal = Marshal.dump klass

    open path, 'wb' do |io|
      io.write marshal
    end
  end


  def save_method klass, method
    full_name = klass.full_name

    FileUtils.mkdir_p class_path(full_name) unless @dry_run

    cache = if method.singleton then
              @cache[:class_methods]
            else
              @cache[:instance_methods]
            end
    cache[full_name] ||= []
    cache[full_name] << method.name

    return if @dry_run

    marshal = Marshal.dump method

    open method_file(full_name, method.full_name), 'wb' do |io|
      io.write marshal
    end
  end


  def save_page page
    return unless page.text?

    path = page_file page.full_name

    FileUtils.mkdir_p File.dirname(path) unless @dry_run

    cache[:pages] ||= []
    cache[:pages] << page.full_name

    return if @dry_run

    marshal = Marshal.dump page

    open path, 'wb' do |io|
      io.write marshal
    end
  end


  def source
    case type
    when :gem    then File.basename File.expand_path '..', @path
    when :home   then 'home'
    when :site   then 'site'
    when :system then 'ruby'
    else @path
    end
  end


  def title
    @cache[:title]
  end


  def title= title
    @cache[:title] = title
  end


  def unique_classes
    @unique_classes
  end


  def unique_classes_and_modules
    @unique_classes + @unique_modules
  end


  def unique_modules
    @unique_modules
  end

end

