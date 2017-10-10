require 'rexml/xmltokens'

module REXML
  module Namespace
    attr_reader :name, :expanded_name
    attr_accessor :prefix
    include XMLTokens
    NAMESPLIT = /^(?:(#{NCNAME_STR}):)?(#{NCNAME_STR})/u

    def name=( name )
      @expanded_name = name
      name =~ NAMESPLIT
      if $1
        @prefix = $1
      else
        @prefix = ""
        @namespace = ""
      end
      @name = $2
    end

    def has_name?( other, ns=nil )
      if ns
        return (namespace() == ns and name() == other)
      elsif other.include? ":"
        return fully_expanded_name == other
      else
        return name == other
      end
    end

    alias :local_name :name

    def fully_expanded_name
      ns = prefix
      return "#{ns}:#@name" if ns.size > 0
      return @name
    end
  end
end
