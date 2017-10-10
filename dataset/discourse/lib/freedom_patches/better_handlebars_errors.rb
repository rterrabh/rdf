module Ember
  module Handlebars
    class Template < Tilt::Template

      def compile_ember_handlebars(string, ember_template = 'Handlebars')
        if ::Rails.env.development?
          "(function() { try { return Ember.#{ember_template}.compile(#{indent(string).inspect}); } catch(err) { throw err; } })()"
        else
          "Ember.#{ember_template}.compile(#{indent(string).inspect});"
        end
      end
    end
  end
end

