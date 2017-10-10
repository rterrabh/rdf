
module XMLRPC # :nodoc:

  module Config

    DEFAULT_WRITER = XMLWriter::Simple

    DEFAULT_PARSER = XMLParser::REXMLStreamParser

    ENABLE_NIL_CREATE    = false
    ENABLE_NIL_PARSER    = false

    ENABLE_BIGINT        = false

    ENABLE_MARSHALLING   = true

    ENABLE_MULTICALL     = false

    ENABLE_INTROSPECTION = false

  end

end

