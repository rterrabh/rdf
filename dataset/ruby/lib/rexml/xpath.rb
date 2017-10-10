require 'rexml/functions'
require 'rexml/xpath_parser'

module REXML
  class XPath
    include Functions
    EMPTY_HASH = {}

    def XPath::first element, path=nil, namespaces=nil, variables={}
      raise "The namespaces argument, if supplied, must be a hash object." unless namespaces.nil? or namespaces.kind_of?(Hash)
      raise "The variables argument, if supplied, must be a hash object." unless variables.kind_of?(Hash)
      parser = XPathParser.new
      parser.namespaces = namespaces
      parser.variables = variables
      path = "*" unless path
      element = [element] unless element.kind_of? Array
      parser.parse(path, element).flatten[0]
    end

    def XPath::each element, path=nil, namespaces=nil, variables={}, &block
      raise "The namespaces argument, if supplied, must be a hash object." unless namespaces.nil? or namespaces.kind_of?(Hash)
      raise "The variables argument, if supplied, must be a hash object." unless variables.kind_of?(Hash)
      parser = XPathParser.new
      parser.namespaces = namespaces
      parser.variables = variables
      path = "*" unless path
      element = [element] unless element.kind_of? Array
      parser.parse(path, element).each( &block )
    end

    def XPath::match element, path=nil, namespaces=nil, variables={}
      parser = XPathParser.new
      parser.namespaces = namespaces
      parser.variables = variables
      path = "*" unless path
      element = [element] unless element.kind_of? Array
      parser.parse(path,element)
    end
  end
end
