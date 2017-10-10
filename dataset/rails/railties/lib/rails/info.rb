require "cgi"

module Rails
  module Info
    mattr_accessor :properties
    class << (@@properties = [])
      def names
        map {|val| val.first }
      end

      def value_for(property_name)
        if property = assoc(property_name)
          property.last
        end
      end
    end

    class << self #:nodoc:
      def property(name, value = nil)
        value ||= yield
        properties << [name, value] if value
      rescue Exception
      end

      def to_s
        column_width = properties.names.map {|name| name.length}.max
        info = properties.map do |name, value|
          value = value.join(", ") if value.is_a?(Array)
          "%-#{column_width}s   %s" % [name, value]
        end
        info.unshift "About your application's environment"
        info * "\n"
      end

      alias inspect to_s

      def to_html
        '<table>'.tap do |table|
          properties.each do |(name, value)|
            table << %(<tr><td class="name">#{CGI.escapeHTML(name.to_s)}</td>)
            formatted_value = if value.kind_of?(Array)
                  "<ul>" + value.map { |v| "<li>#{CGI.escapeHTML(v.to_s)}</li>" }.join + "</ul>"
                else
                  CGI.escapeHTML(value.to_s)
                end
            table << %(<td class="value">#{formatted_value}</td></tr>)
          end
          table << '</table>'
        end
      end
    end

    property 'Rails version' do
      Rails.version.to_s
    end

    property 'Ruby version' do
      "#{RUBY_VERSION}-p#{RUBY_PATCHLEVEL} (#{RUBY_PLATFORM})"
    end

    property 'RubyGems version' do
      Gem::RubyGemsVersion
    end

    property 'Rack version' do
      ::Rack.release
    end

    property 'JavaScript Runtime' do
      ExecJS.runtime.name
    end

    property 'Middleware' do
      Rails.configuration.middleware.map(&:inspect)
    end

    property 'Application root' do
      File.expand_path(Rails.root)
    end

    property 'Environment' do
      Rails.env
    end

    property 'Database adapter' do
      ActiveRecord::Base.configurations[Rails.env]['adapter']
    end

    property 'Database schema version' do
      ActiveRecord::Migrator.current_version rescue nil
    end
  end
end
