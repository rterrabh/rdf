module REXML
  module StreamListener
    def tag_start name, attrs
    end
    def tag_end name
    end
    def text text
    end
    def instruction name, instruction
    end
    def comment comment
    end
    def doctype name, pub_sys, long_name, uri
    end
    def doctype_end
    end
    def attlistdecl element_name, attributes, raw_content
    end
    def elementdecl content
    end
    def entitydecl content
    end
    def notationdecl content
    end
    def entity content
    end
    def cdata content
    end
    def xmldecl version, encoding, standalone
    end
  end
end
