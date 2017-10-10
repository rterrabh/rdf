require 'rexml/child'
require 'rexml/source'

module REXML
  class AttlistDecl < Child
    include Enumerable

    attr_reader :element_name

    def initialize(source)
      super()
      if (source.kind_of? Array)
        @element_name, @pairs, @contents = *source
      end
    end

    def [](key)
      @pairs[key]
    end

    def include?(key)
      @pairs.keys.include? key
    end

    def each(&block)
      @pairs.each(&block)
    end

    def write out, indent=-1
      out << @contents
    end

    def node_type
      :attlistdecl
    end
  end
end
