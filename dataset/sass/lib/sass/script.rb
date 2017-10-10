require 'sass/scss/rx'

module Sass
  module Script
    MATCH = /^\$(#{Sass::SCSS::RX::IDENT})\s*:\s*(.+?)
      (!#{Sass::SCSS::RX::IDENT}(?:\s+!#{Sass::SCSS::RX::IDENT})*)?$/x

    VALIDATE = /^\$#{Sass::SCSS::RX::IDENT}$/

    def self.parse(value, line, offset, options = {})
      Parser.parse(value, line, offset, options)
    rescue Sass::SyntaxError => e
      e.message << ": #{value.inspect}." if e.message == "SassScript error"
      e.modify_backtrace(:line => line, :filename => options[:filename])
      raise e
    end

    require 'sass/script/functions'
    require 'sass/script/parser'
    require 'sass/script/tree'
    require 'sass/script/value'

    CONST_RENAMES = {
      :Literal => Sass::Script::Value::Base,
      :ArgList => Sass::Script::Value::ArgList,
      :Bool => Sass::Script::Value::Bool,
      :Color => Sass::Script::Value::Color,
      :List => Sass::Script::Value::List,
      :Null => Sass::Script::Value::Null,
      :Number => Sass::Script::Value::Number,
      :String => Sass::Script::Value::String,
      :Node => Sass::Script::Tree::Node,
      :Funcall => Sass::Script::Tree::Funcall,
      :Interpolation => Sass::Script::Tree::Interpolation,
      :Operation => Sass::Script::Tree::Operation,
      :StringInterpolation => Sass::Script::Tree::StringInterpolation,
      :UnaryOperation => Sass::Script::Tree::UnaryOperation,
      :Variable => Sass::Script::Tree::Variable,
    }

    def self.const_missing(name)
      klass = CONST_RENAMES[name]
      super unless klass
      #nodyna <const_set-3037> <not yet classified>
      CONST_RENAMES.each {|n, k| const_set(n, k)}
      klass
    end
  end
end
