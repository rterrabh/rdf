module REXML
  module SAX2Listener
    def start_document
    end
    def end_document
    end
    def start_prefix_mapping prefix, uri
    end
    def end_prefix_mapping prefix
    end
    def start_element uri, localname, qname, attributes
    end
    def end_element uri, localname, qname
    end
    def characters text
    end
    def processing_instruction target, data
    end
    def doctype name, pub_sys, long_name, uri
    end
    def attlistdecl(element, pairs, contents)
    end
    def elementdecl content
    end
    def entitydecl declaration
    end
    def notationdecl name, public_or_system, public_id, system_id
    end
    def cdata content
    end
    def xmldecl version, encoding, standalone
    end
    def comment comment
    end
    def progress position
    end
  end
end
