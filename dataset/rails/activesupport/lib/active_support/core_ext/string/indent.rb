class String
  def indent!(amount, indent_string=nil, indent_empty_lines=false)
    indent_string = indent_string || self[/^[ \t]/] || ' '
    re = indent_empty_lines ? /^/ : /^(?!$)/
    gsub!(re, indent_string * amount)
  end

  def indent(amount, indent_string=nil, indent_empty_lines=false)
    dup.tap {|_| _.indent!(amount, indent_string, indent_empty_lines)}
  end
end
