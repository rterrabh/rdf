class CGI
  module TagMaker # :nodoc:

    def nn_element(element, attributes = {})
      s = nOE_element(element, attributes)
      if block_given?
        s << yield.to_s
      end
      s << "</#{element.upcase}>"
    end

    def nn_element_def(attributes = {}, &block)
      nn_element(__callee__, attributes, &block)
    end

    def nOE_element(element, attributes = {})
      attributes={attributes=>nil} if attributes.kind_of?(String)
      s = "<#{element.upcase}"
      attributes.each do|name, value|
        next unless value
        s << " "
        s << CGI::escapeHTML(name.to_s)
        if value != true
          s << '="'
          s << CGI::escapeHTML(value.to_s)
          s << '"'
        end
      end
      s << ">"
    end

    def nOE_element_def(attributes = {}, &block)
      nOE_element(__callee__, attributes, &block)
    end


    def nO_element(element, attributes = {})
      s = nOE_element(element, attributes)
      if block_given?
        s << yield.to_s
        s << "</#{element.upcase}>"
      end
      s
    end

    def nO_element_def(attributes = {}, &block)
      nO_element(__callee__, attributes, &block)
    end

  end # TagMaker


  module HtmlExtension


    def a(href = "") # :yield:
      attributes = if href.kind_of?(String)
                     { "HREF" => href }
                   else
                     href
                   end
      super(attributes)
    end

    def base(href = "") # :yield:
      attributes = if href.kind_of?(String)
                     { "HREF" => href }
                   else
                     href
                   end
      super(attributes)
    end

    def blockquote(cite = {})  # :yield:
      attributes = if cite.kind_of?(String)
                     { "CITE" => cite }
                   else
                     cite
                   end
      super(attributes)
    end


    def caption(align = {}) # :yield:
      attributes = if align.kind_of?(String)
                     { "ALIGN" => align }
                   else
                     align
                   end
      super(attributes)
    end


    def checkbox(name = "", value = nil, checked = nil)
      attributes = if name.kind_of?(String)
                     { "TYPE" => "checkbox", "NAME" => name,
                       "VALUE" => value, "CHECKED" => checked }
                   else
                     name["TYPE"] = "checkbox"
                     name
                   end
      input(attributes)
    end

    def checkbox_group(name = "", *values)
      if name.kind_of?(Hash)
        values = name["VALUES"]
        name = name["NAME"]
      end
      values.collect{|value|
        if value.kind_of?(String)
          checkbox(name, value) + value
        else
          if value[-1] == true || value[-1] == false
            checkbox(name, value[0],  value[-1]) +
            value[-2]
          else
            checkbox(name, value[0]) +
            value[-1]
          end
        end
      }.join
    end


    def file_field(name = "", size = 20, maxlength = nil)
      attributes = if name.kind_of?(String)
                     { "TYPE" => "file", "NAME" => name,
                       "SIZE" => size.to_s }
                   else
                     name["TYPE"] = "file"
                     name
                   end
      attributes["MAXLENGTH"] = maxlength.to_s if maxlength
      input(attributes)
    end


    def form(method = "post", action = script_name, enctype = "application/x-www-form-urlencoded")
      attributes = if method.kind_of?(String)
                     { "METHOD" => method, "ACTION" => action,
                       "ENCTYPE" => enctype }
                   else
                     unless method.has_key?("METHOD")
                       method["METHOD"] = "post"
                     end
                     unless method.has_key?("ENCTYPE")
                       method["ENCTYPE"] = enctype
                     end
                     method
                   end
      if block_given?
        body = yield
      else
        body = ""
      end
      if @output_hidden
        body << @output_hidden.collect{|k,v|
          "<INPUT TYPE=\"HIDDEN\" NAME=\"#{k}\" VALUE=\"#{v}\">"
        }.join
      end
      super(attributes){body}
    end

    def hidden(name = "", value = nil)
      attributes = if name.kind_of?(String)
                     { "TYPE" => "hidden", "NAME" => name, "VALUE" => value }
                   else
                     name["TYPE"] = "hidden"
                     name
                   end
      input(attributes)
    end

    def html(attributes = {}) # :yield:
      if nil == attributes
        attributes = {}
      elsif "PRETTY" == attributes
        attributes = { "PRETTY" => true }
      end
      pretty = attributes.delete("PRETTY")
      pretty = "  " if true == pretty
      buf = ""

      if attributes.has_key?("DOCTYPE")
        if attributes["DOCTYPE"]
          buf << attributes.delete("DOCTYPE")
        else
          attributes.delete("DOCTYPE")
        end
      else
        buf << doctype
      end

      buf << super(attributes)

      if pretty
        CGI::pretty(buf, pretty)
      else
        buf
      end

    end

    def image_button(src = "", name = nil, alt = nil)
      attributes = if src.kind_of?(String)
                     { "TYPE" => "image", "SRC" => src, "NAME" => name,
                       "ALT" => alt }
                   else
                     src["TYPE"] = "image"
                     src["SRC"] ||= ""
                     src
                   end
      input(attributes)
    end


    def img(src = "", alt = "", width = nil, height = nil)
      attributes = if src.kind_of?(String)
                     { "SRC" => src, "ALT" => alt }
                   else
                     src
                   end
      attributes["WIDTH"] = width.to_s if width
      attributes["HEIGHT"] = height.to_s if height
      super(attributes)
    end


    def multipart_form(action = nil, enctype = "multipart/form-data")
      attributes = if action == nil
                     { "METHOD" => "post", "ENCTYPE" => enctype }
                   elsif action.kind_of?(String)
                     { "METHOD" => "post", "ACTION" => action,
                       "ENCTYPE" => enctype }
                   else
                     unless action.has_key?("METHOD")
                       action["METHOD"] = "post"
                     end
                     unless action.has_key?("ENCTYPE")
                       action["ENCTYPE"] = enctype
                     end
                     action
                   end
      if block_given?
        form(attributes){ yield }
      else
        form(attributes)
      end
    end


    def password_field(name = "", value = nil, size = 40, maxlength = nil)
      attributes = if name.kind_of?(String)
                     { "TYPE" => "password", "NAME" => name,
                       "VALUE" => value, "SIZE" => size.to_s }
                   else
                     name["TYPE"] = "password"
                     name
                   end
      attributes["MAXLENGTH"] = maxlength.to_s if maxlength
      input(attributes)
    end

    def popup_menu(name = "", *values)

      if name.kind_of?(Hash)
        values   = name["VALUES"]
        size     = name["SIZE"].to_s if name["SIZE"]
        multiple = name["MULTIPLE"]
        name     = name["NAME"]
      else
        size = nil
        multiple = nil
      end

      select({ "NAME" => name, "SIZE" => size,
               "MULTIPLE" => multiple }){
        values.collect{|value|
          if value.kind_of?(String)
            option({ "VALUE" => value }){ value }
          else
            if value[value.size - 1] == true
              option({ "VALUE" => value[0], "SELECTED" => true }){
                value[value.size - 2]
              }
            else
              option({ "VALUE" => value[0] }){
                value[value.size - 1]
              }
            end
          end
        }.join
      }

    end

    def radio_button(name = "", value = nil, checked = nil)
      attributes = if name.kind_of?(String)
                     { "TYPE" => "radio", "NAME" => name,
                       "VALUE" => value, "CHECKED" => checked }
                   else
                     name["TYPE"] = "radio"
                     name
                   end
      input(attributes)
    end

    def radio_group(name = "", *values)
      if name.kind_of?(Hash)
        values = name["VALUES"]
        name = name["NAME"]
      end
      values.collect{|value|
        if value.kind_of?(String)
          radio_button(name, value) + value
        else
          if value[-1] == true || value[-1] == false
            radio_button(name, value[0],  value[-1]) +
            value[-2]
          else
            radio_button(name, value[0]) +
            value[-1]
          end
        end
      }.join
    end

    def reset(value = nil, name = nil)
      attributes = if (not value) or value.kind_of?(String)
                     { "TYPE" => "reset", "VALUE" => value, "NAME" => name }
                   else
                     value["TYPE"] = "reset"
                     value
                   end
      input(attributes)
    end

    alias scrolling_list popup_menu

    def submit(value = nil, name = nil)
      attributes = if (not value) or value.kind_of?(String)
                     { "TYPE" => "submit", "VALUE" => value, "NAME" => name }
                   else
                     value["TYPE"] = "submit"
                     value
                   end
      input(attributes)
    end

    def text_field(name = "", value = nil, size = 40, maxlength = nil)
      attributes = if name.kind_of?(String)
                     { "TYPE" => "text", "NAME" => name, "VALUE" => value,
                       "SIZE" => size.to_s }
                   else
                     name["TYPE"] = "text"
                     name
                   end
      attributes["MAXLENGTH"] = maxlength.to_s if maxlength
      input(attributes)
    end

    def textarea(name = "", cols = 70, rows = 10)  # :yield:
      attributes = if name.kind_of?(String)
                     { "NAME" => name, "COLS" => cols.to_s,
                       "ROWS" => rows.to_s }
                   else
                     name
                   end
      super(attributes)
    end

  end # HtmlExtension


  module Html3 # :nodoc:
    include TagMaker

    def doctype
      %|<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 3.2 Final//EN">|
    end

    instance_method(:nn_element_def).tap do |m|
      for element in %w[ A TT I B U STRIKE BIG SMALL SUB SUP EM STRONG
          DFN CODE SAMP KBD VAR CITE FONT ADDRESS DIV CENTER MAP
          APPLET PRE XMP LISTING DL OL UL DIR MENU SELECT TABLE TITLE
          STYLE SCRIPT H1 H2 H3 H4 H5 H6 TEXTAREA FORM BLOCKQUOTE
          CAPTION ]
        #nodyna <define_method-1936> <DM MODERATE (array)>
        define_method(element.downcase, m)
      end
    end

    instance_method(:nOE_element_def).tap do |m|
      for element in %w[ IMG BASE BASEFONT BR AREA LINK PARAM HR INPUT
          ISINDEX META ]
        #nodyna <define_method-1937> <DM MODERATE (array)>
        define_method(element.downcase, m)
      end
    end

    instance_method(:nO_element_def).tap do |m|
      for element in %w[ HTML HEAD BODY P PLAINTEXT DT DD LI OPTION TR
          TH TD ]
        #nodyna <define_method-1938> <DM MODERATE (array)>
        define_method(element.downcase, m)
      end
    end

  end # Html3


  module Html4 # :nodoc:
    include TagMaker

    def doctype
      %|<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01//EN" "http://www.w3.org/TR/html4/strict.dtd">|
    end

    instance_method(:nn_element_def).tap do |m|
      for element in %w[ TT I B BIG SMALL EM STRONG DFN CODE SAMP KBD
        VAR CITE ABBR ACRONYM SUB SUP SPAN BDO ADDRESS DIV MAP OBJECT
        H1 H2 H3 H4 H5 H6 PRE Q INS DEL DL OL UL LABEL SELECT OPTGROUP
        FIELDSET LEGEND BUTTON TABLE TITLE STYLE SCRIPT NOSCRIPT
        TEXTAREA FORM A BLOCKQUOTE CAPTION ]
        #nodyna <define_method-1939> <DM MODERATE (array)>
        define_method(element.downcase, m)
      end
    end

    instance_method(:nOE_element_def).tap do |m|
      for element in %w[ IMG BASE BR AREA LINK PARAM HR INPUT COL META ]
        #nodyna <define_method-1940> <DM MODERATE (array)>
        define_method(element.downcase, m)
      end
    end

    instance_method(:nO_element_def).tap do |m|
      for element in %w[ HTML BODY P DT DD LI OPTION THEAD TFOOT TBODY
          COLGROUP TR TH TD HEAD ]
        #nodyna <define_method-1941> <DM MODERATE (array)>
        define_method(element.downcase, m)
      end
    end

  end # Html4


  module Html4Tr # :nodoc:
    include TagMaker

    def doctype
      %|<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN" "http://www.w3.org/TR/html4/loose.dtd">|
    end

    instance_method(:nn_element_def).tap do |m|
      for element in %w[ TT I B U S STRIKE BIG SMALL EM STRONG DFN
          CODE SAMP KBD VAR CITE ABBR ACRONYM FONT SUB SUP SPAN BDO
          ADDRESS DIV CENTER MAP OBJECT APPLET H1 H2 H3 H4 H5 H6 PRE Q
          INS DEL DL OL UL DIR MENU LABEL SELECT OPTGROUP FIELDSET
          LEGEND BUTTON TABLE IFRAME NOFRAMES TITLE STYLE SCRIPT
          NOSCRIPT TEXTAREA FORM A BLOCKQUOTE CAPTION ]
        #nodyna <define_method-1942> <DM MODERATE (array)>
        define_method(element.downcase, m)
      end
    end

    instance_method(:nOE_element_def).tap do |m|
      for element in %w[ IMG BASE BASEFONT BR AREA LINK PARAM HR INPUT
          COL ISINDEX META ]
        #nodyna <define_method-1943> <DM MODERATE (array)>
        define_method(element.downcase, m)
      end
    end

    instance_method(:nO_element_def).tap do |m|
      for element in %w[ HTML BODY P DT DD LI OPTION THEAD TFOOT TBODY
          COLGROUP TR TH TD HEAD ]
        #nodyna <define_method-1944> <DM MODERATE (array)>
        define_method(element.downcase, m)
      end
    end

  end # Html4Tr


  module Html4Fr # :nodoc:
    include TagMaker

    def doctype
      %|<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Frameset//EN" "http://www.w3.org/TR/html4/frameset.dtd">|
    end

    instance_method(:nn_element_def).tap do |m|
      for element in %w[ FRAMESET ]
        #nodyna <define_method-1945> <DM MODERATE (array)>
        define_method(element.downcase, m)
      end
    end

    instance_method(:nOE_element_def).tap do |m|
      for element in %w[ FRAME ]
        #nodyna <define_method-1946> <DM MODERATE (array)>
        define_method(element.downcase, m)
      end
    end

  end # Html4Fr


  module Html5 # :nodoc:
    include TagMaker

    def doctype
      %|<!DOCTYPE HTML>|
    end

    instance_method(:nn_element_def).tap do |m|
      for element in %w[ SECTION NAV ARTICLE ASIDE HGROUP HEADER
        FOOTER FIGURE FIGCAPTION S TIME U MARK RUBY BDI IFRAME
        VIDEO AUDIO CANVAS DATALIST OUTPUT PROGRESS METER DETAILS
        SUMMARY MENU DIALOG I B SMALL EM STRONG DFN CODE SAMP KBD
        VAR CITE ABBR SUB SUP SPAN BDO ADDRESS DIV MAP OBJECT
        H1 H2 H3 H4 H5 H6 PRE Q INS DEL DL OL UL LABEL SELECT
        FIELDSET LEGEND BUTTON TABLE TITLE STYLE SCRIPT NOSCRIPT
        TEXTAREA FORM A BLOCKQUOTE CAPTION ]
        #nodyna <define_method-1947> <DM MODERATE (array)>
        define_method(element.downcase, m)
      end
    end

    instance_method(:nOE_element_def).tap do |m|
      for element in %w[ IMG BASE BR AREA LINK PARAM HR INPUT COL META
        COMMAND EMBED KEYGEN SOURCE TRACK WBR ]
        #nodyna <define_method-1948> <DM MODERATE (array)>
        define_method(element.downcase, m)
      end
    end

    instance_method(:nO_element_def).tap do |m|
      for element in %w[ HTML HEAD BODY P DT DD LI OPTION THEAD TFOOT TBODY
          OPTGROUP COLGROUP RT RP TR TH TD ]
        #nodyna <define_method-1949> <DM MODERATE (array)>
        define_method(element.downcase, m)
      end
    end

  end # Html5

  class HTML3
    include Html3
    include HtmlExtension
  end

  class HTML4
    include Html4
    include HtmlExtension
  end

  class HTML4Tr
    include Html4Tr
    include HtmlExtension
  end

  class HTML4Fr
    include Html4Tr
    include Html4Fr
    include HtmlExtension
  end

  class HTML5
    include Html5
    include HtmlExtension
  end

end
