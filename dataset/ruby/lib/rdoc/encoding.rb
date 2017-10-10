

module RDoc::Encoding


  def self.read_file filename, encoding, force_transcode = false
    content = open filename, "rb" do |f| f.read end
    content.gsub!("\r\n", "\n") if RUBY_PLATFORM =~ /mswin|mingw/

    utf8 = content.sub!(/\A\xef\xbb\xbf/, '')

    RDoc::Encoding.set_encoding content

    if Object.const_defined? :Encoding then
      begin
        encoding ||= Encoding.default_external
        orig_encoding = content.encoding

        if not orig_encoding.ascii_compatible? then
          content.encode! encoding
        elsif utf8 then
          content.force_encoding Encoding::UTF_8
          content.encode! encoding
        else
          content.force_encoding encoding
        end

        unless content.valid_encoding? then
          content.force_encoding orig_encoding
          content.encode! encoding
        end

        unless content.valid_encoding? then
          warn "unable to convert #{filename} to #{encoding}, skipping"
          content = nil
        end
      rescue Encoding::InvalidByteSequenceError,
             Encoding::UndefinedConversionError => e
        if force_transcode then
          content.force_encoding orig_encoding
          content.encode!(encoding,
                          :invalid => :replace, :undef => :replace,
                          :replace => '?')
          return content
        else
          warn "unable to convert #{e.message} for #{filename}, skipping"
          return nil
        end
      end
    end

    content
  rescue ArgumentError => e
    raise unless e.message =~ /unknown encoding name - (.*)/
    warn "unknown encoding name \"#{$1}\" for #{filename}, skipping"
    nil
  rescue Errno::EISDIR, Errno::ENOENT
    nil
  end


  def self.set_encoding string
    string =~ /\A(?:#!.*\n)?(.*\n)/

    first_line = $1

    name = case first_line
           when /^<\?xml[^?]*encoding=(["'])(.*?)\1/ then $2
           when /\b(?:en)?coding[=:]\s*([^\s;]+)/i   then $1
           else                                           return
           end

    string.sub! first_line, ''

    return unless Object.const_defined? :Encoding

    enc = Encoding.find name
    string.force_encoding enc if enc
  end

end

