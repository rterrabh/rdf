require 'psych/json/yaml_events'

module Psych
  module JSON
    class TreeBuilder < Psych::TreeBuilder
      include Psych::JSON::YAMLEvents
    end
  end
end
