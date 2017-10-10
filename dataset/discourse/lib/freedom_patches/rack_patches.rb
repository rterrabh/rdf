class Rack::ETag
  private

   def digest_body(body)
    parts = []
    has_body = false

    body.each do |part|
      parts << part
      has_body ||= part.length > 0
    end

    hexdigest =
      if has_body
        digest = Digest::MD5.new
        parts.each { |part| digest << part }
        digest.hexdigest
      end

    [hexdigest, parts]
  end
end

class Rack::ConditionalGet
  private
   def to_rfc2822(since)
    if since && since.length >= 16
      Time.rfc2822(since) rescue nil
    else
      nil
    end
  end
end
