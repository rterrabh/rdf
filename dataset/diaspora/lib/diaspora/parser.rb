
module Diaspora
  module Parser
    def self.from_xml(xml)
      doc = Nokogiri::XML(xml) {|cfg| cfg.noblanks }
      return unless body = doc.xpath("/XML/post").children.first
      class_name = body.name.gsub("-", "/")
      ::Logging::Logger["XMLLogger"].debug "from_xml: #{body}"
      begin
        class_name.camelize.constantize.from_xml body.to_s
      rescue NameError => e
        ::Logging::Logger[self].warn("Error while parsing the xml: #{e.message}")
        nil
      end
    end
  end
end
