class String
  unless method_defined? :scrub
    def scrub(replace_char=nil)
      str = dup.force_encoding("utf-8")

      unless str.valid_encoding?
        str.encode!("utf-16","utf-8",:invalid => :replace)
        str.encode!("utf-8","utf-16")
      end

      str
    end
  end
end
