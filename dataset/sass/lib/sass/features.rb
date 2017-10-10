require 'set'
module Sass
  module Features
    KNOWN_FEATURES = Set[*%w{
      global-variable-shadowing
      extend-selector-pseudoclass
      units-level-3
      at-error
    }]

    def has_feature?(feature_name)
      KNOWN_FEATURES.include?(feature_name)
    end

    def add_feature(feature_name)
      unless feature_name[0] == ?-
        raise ArgumentError.new("Plugin feature names must begin with a dash")
      end
      KNOWN_FEATURES << feature_name
    end
  end

  extend Features
end
