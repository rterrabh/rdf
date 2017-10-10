require 'psych.so'
require 'psych/nodes'
require 'psych/streaming'
require 'psych/visitors'
require 'psych/handler'
require 'psych/tree_builder'
require 'psych/parser'
require 'psych/omap'
require 'psych/set'
require 'psych/coder'
require 'psych/core_ext'
require 'psych/deprecated'
require 'psych/stream'
require 'psych/json/tree_builder'
require 'psych/json/stream'
require 'psych/handlers/document_stream'
require 'psych/class_loader'


module Psych
  VERSION         = '2.0.8'

  LIBYAML_VERSION = Psych.libyaml_version.join '.'

  def self.load yaml, filename = nil
    result = parse(yaml, filename)
    result ? result.to_ruby : result
  end

  def self.safe_load yaml, whitelist_classes = [], whitelist_symbols = [], aliases = false, filename = nil
    result = parse(yaml, filename)
    return unless result

    class_loader = ClassLoader::Restricted.new(whitelist_classes.map(&:to_s),
                                               whitelist_symbols.map(&:to_s))
    scanner      = ScalarScanner.new class_loader
    if aliases
      visitor = Visitors::ToRuby.new scanner, class_loader
    else
      visitor = Visitors::NoAliasRuby.new scanner, class_loader
    end
    visitor.accept result
  end

  def self.parse yaml, filename = nil
    parse_stream(yaml, filename) do |node|
      return node
    end
    false
  end

  def self.parse_file filename
    File.open filename, 'r:bom|utf-8' do |f|
      parse f, filename
    end
  end

  def self.parser
    Psych::Parser.new(TreeBuilder.new)
  end

  def self.parse_stream yaml, filename = nil, &block
    if block_given?
      parser = Psych::Parser.new(Handlers::DocumentStream.new(&block))
      parser.parse yaml, filename
    else
      parser = self.parser
      parser.parse yaml, filename
      parser.handler.root
    end
  end

  def self.dump o, io = nil, options = {}
    if Hash === io
      options = io
      io      = nil
    end

    visitor = Psych::Visitors::YAMLTree.create options
    visitor << o
    visitor.tree.yaml io, options
  end

  def self.dump_stream *objects
    visitor = Psych::Visitors::YAMLTree.create({})
    objects.each do |o|
      visitor << o
    end
    visitor.tree.yaml
  end

  def self.to_json object
    visitor = Psych::Visitors::JSONTree.create
    visitor << object
    visitor.tree.yaml
  end

  def self.load_stream yaml, filename = nil
    if block_given?
      parse_stream(yaml, filename) do |node|
        yield node.to_ruby
      end
    else
      parse_stream(yaml, filename).children.map { |child| child.to_ruby }
    end
  end

  def self.load_file filename
    File.open(filename, 'r:bom|utf-8') { |f| self.load f, filename }
  end

  @domain_types = {}
  def self.add_domain_type domain, type_tag, &block
    key = ['tag', domain, type_tag].join ':'
    @domain_types[key] = [key, block]
    @domain_types["tag:#{type_tag}"] = [key, block]
  end

  def self.add_builtin_type type_tag, &block
    domain = 'yaml.org,2002'
    key = ['tag', domain, type_tag].join ':'
    @domain_types[key] = [key, block]
  end

  def self.remove_type type_tag
    @domain_types.delete type_tag
  end

  @load_tags = {}
  @dump_tags = {}
  def self.add_tag tag, klass
    @load_tags[tag] = klass.name
    @dump_tags[klass] = tag
  end

  class << self
    attr_accessor :load_tags
    attr_accessor :dump_tags
    attr_accessor :domain_types
  end
end
