module ActionController
  module Head
    def head(status, options = {})
      options, status = status, nil if status.is_a?(Hash)
      status ||= options.delete(:status) || :ok
      location = options.delete(:location)
      content_type = options.delete(:content_type)

      options.each do |key, value|
        headers[key.to_s.dasherize.split('-').each { |v| v[0] = v[0].chr.upcase }.join('-')] = value.to_s
      end

      self.status = status
      self.location = url_for(location) if location

      self.response_body = ""

      if include_content?(self.response_code)
        self.content_type = content_type || (Mime[formats.first] if formats)
        self.response.charset = false if self.response
      else
        headers.delete('Content-Type')
        headers.delete('Content-Length')
      end
      
      true
    end

    private
    def include_content?(status)
      case status
      when 100..199
        false
      when 204, 205, 304
        false
      else
        true
      end
    end
  end
end
