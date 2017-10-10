
begin
  require 'psych'
rescue LoadError
  warn "#{caller[0]}:"
  warn "It seems your ruby installation is missing psych (for YAML output)."
  warn "To eliminate this warning, please install libyaml and reinstall your ruby."
  raise
end

YAML = Psych # :nodoc:

module YAML
end
