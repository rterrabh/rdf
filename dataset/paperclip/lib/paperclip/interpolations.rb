module Paperclip
  module Interpolations
    extend self

    def self.[]= name, block
      #nodyna <define_method-702> <DM COMPLEX (events)>
      define_method(name, &block)
    end

    def self.[] name
      method(name)
    end

    def self.all
      self.instance_methods(false).sort
    end

    def self.interpolate pattern, *args
      #nodyna <send-703> <SD COMPLEX (change-prone variables)>
      pattern = args.first.instance.send(pattern) if pattern.kind_of? Symbol
      all.reverse.inject(pattern) do |result, tag|
        result.gsub(/:#{tag}/) do |match|
          #nodyna <send-704> <SD COMPLEX (change-prone variables)>
          send( tag, *args )
        end
      end
    end

    def self.plural_cache
      @plural_cache ||= PluralCache.new
    end

    def filename attachment, style_name
      [ basename(attachment, style_name), extension(attachment, style_name) ].reject(&:blank?).join(".")
    end

    RIGHT_HERE = "#{__FILE__.gsub(%r{\A\./}, "")}:#{__LINE__ + 3}"
    def url attachment, style_name
      raise Errors::InfiniteInterpolationError if caller.any?{|b| b.index(RIGHT_HERE) }
      attachment.url(style_name, :timestamp => false, :escape => false)
    end

    def timestamp attachment, style_name
      attachment.instance_read(:updated_at).in_time_zone(attachment.time_zone).to_s
    end

    def updated_at attachment, style_name
      attachment.updated_at
    end

    def rails_root attachment, style_name
      Rails.root
    end

    def rails_env attachment, style_name
      Rails.env
    end

    def class attachment = nil, style_name = nil
      return super() if attachment.nil? && style_name.nil?
      plural_cache.underscore_and_pluralize(attachment.instance.class.to_s)
    end

    def basename attachment, style_name
      attachment.original_filename.gsub(/#{Regexp.escape(File.extname(attachment.original_filename))}\Z/, "")
    end

    def extension attachment, style_name
      ((style = attachment.styles[style_name.to_s.to_sym]) && style[:format]) ||
        File.extname(attachment.original_filename).gsub(/\A\.+/, "")
    end

    def dotextension attachment, style_name
      ext = extension(attachment, style_name)
      ext.empty? ? "" : ".#{ext}"
    end

    def content_type_extension attachment, style_name
      mime_type = MIME::Types[attachment.content_type]
      extensions_for_mime_type = unless mime_type.empty?
        mime_type.first.extensions
      else
        []
      end

      original_extension = extension(attachment, style_name)
      style = attachment.styles[style_name.to_s.to_sym]
      if style && style[:format]
        style[:format].to_s
      elsif extensions_for_mime_type.include? original_extension
        original_extension
      elsif !extensions_for_mime_type.empty?
        extensions_for_mime_type.first
      else
        %r{/([^/]*)\Z}.match(attachment.content_type)[1]
      end
    end

    def id attachment, style_name
      attachment.instance.id
    end

    def param attachment, style_name
      attachment.instance.to_param
    end

    def fingerprint attachment, style_name
      attachment.fingerprint
    end

    def hash attachment=nil, style_name=nil
      if attachment && style_name
        attachment.hash_key(style_name)
      else
        super()
      end
    end

    def id_partition attachment, style_name
      case id = attachment.instance.id
      when Integer
        ("%09d" % id).scan(/\d{3}/).join("/")
      when String
        id.scan(/.{3}/).first(3).join("/")
      else
        nil
      end
    end

    def attachment attachment, style_name
      plural_cache.pluralize(attachment.name.to_s.downcase)
    end

    def style attachment, style_name
      style_name || attachment.default_style
    end
  end
end
