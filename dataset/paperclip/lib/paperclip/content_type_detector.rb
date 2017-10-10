module Paperclip
  class ContentTypeDetector

    EMPTY_TYPE = "inode/x-empty"
    SENSIBLE_DEFAULT = "application/octet-stream"

    def initialize(filepath)
      @filepath = filepath
    end

    def detect
      if blank_name?
        SENSIBLE_DEFAULT
      elsif empty_file?
        EMPTY_TYPE
      elsif calculated_type_matches.any?
        calculated_type_matches.first
      else
        type_from_file_contents || SENSIBLE_DEFAULT
      end.to_s
    end

    private

    def blank_name?
      @filepath.nil? || @filepath.empty?
    end

    def empty_file?
      File.exist?(@filepath) && File.size(@filepath) == 0
    end

    alias :empty? :empty_file?

    def calculated_type_matches
      possible_types.select do |content_type|
        content_type == type_from_file_contents
      end
    end

    def possible_types
      MIME::Types.type_for(@filepath).collect(&:content_type)
    end

    def type_from_file_contents
      type_from_mime_magic || type_from_file_command
    rescue Errno::ENOENT => e
      Paperclip.log("Error while determining content type: #{e}")
      SENSIBLE_DEFAULT
    end

    def type_from_mime_magic
      @type_from_mime_magic ||=
        MimeMagic.by_magic(File.open(@filepath)).try(:type)
    end

    def type_from_file_command
      @type_from_file_command ||=
        FileCommandContentTypeDetector.new(@filepath).detect
    end
  end
end
