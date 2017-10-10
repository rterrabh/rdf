module Paperclip
  class Tempfile < ::Tempfile
    def make_tmpname(prefix_suffix, n)
      if RUBY_PLATFORM =~ /java/
        case prefix_suffix
        when String
          prefix, suffix = prefix_suffix, ''
        when Array
          prefix, suffix = *prefix_suffix
        else
          raise ArgumentError, "unexpected prefix_suffix: #{prefix_suffix.inspect}"
        end

        t = Time.now.strftime("%y%m%d")
        path = "#{prefix}#{t}-#{$$}-#{rand(0x100000000).to_s(36)}-#{n}#{suffix}"
      else
        super
      end
    end
  end

  module TempfileEncoding
    def binmode
      set_encoding('ASCII-8BIT')
      super
    end
  end
end

if RUBY_PLATFORM =~ /java/
  #nodyna <send-696> <SD TRIVIAL (public methods)>
  ::Tempfile.send :include, Paperclip::TempfileEncoding
end
