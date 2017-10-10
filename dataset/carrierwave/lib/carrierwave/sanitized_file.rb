
require 'pathname'
require 'active_support/core_ext/string/multibyte'
require 'mime/types'

module CarrierWave

  class SanitizedFile

    attr_accessor :file

    class << self
      attr_writer :sanitize_regexp

      def sanitize_regexp
        @sanitize_regexp ||= /[^a-zA-Z0-9\.\-\+_]/
      end
    end

    def initialize(file)
      self.file = file
    end

    def original_filename
      return @original_filename if @original_filename
      if @file and @file.respond_to?(:original_filename)
        @file.original_filename
      elsif path
        File.basename(path)
      end
    end

    def filename
      sanitize(original_filename) if original_filename
    end

    alias_method :identifier, :filename

    def basename
      split_extension(filename)[0] if filename
    end

    def extension
      split_extension(filename)[1] if filename
    end

    def size
      if is_path?
        exists? ? File.size(path) : 0
      elsif @file.respond_to?(:size)
        @file.size
      elsif path
        exists? ? File.size(path) : 0
      else
        0
      end
    end

    def path
      unless @file.blank?
        if is_path?
          File.expand_path(@file)
        elsif @file.respond_to?(:path) and not @file.path.blank?
          File.expand_path(@file.path)
        end
      end
    end

    def is_path?
      !!((@file.is_a?(String) || @file.is_a?(Pathname)) && !@file.blank?)
    end

    def empty?
      @file.nil? || self.size.nil? || (self.size.zero? && ! self.exists?)
    end

    def exists?
      return File.exists?(self.path) if self.path
      return false
    end

    def read
      if @content
        @content
      elsif is_path?
        File.open(@file, "rb") {|file| file.read}
      else
        @file.rewind if @file.respond_to?(:rewind)
        @content = @file.read
        @file.close if @file.respond_to?(:close) && @file.respond_to?(:closed?) && !@file.closed?
        @content
      end
    end

    def move_to(new_path, permissions=nil, directory_permissions=nil)
      return if self.empty?
      new_path = File.expand_path(new_path)

      mkdir!(new_path, directory_permissions)
      if exists?
        FileUtils.mv(path, new_path) unless new_path == path
      else
        File.open(new_path, "wb") { |f| f.write(read) }
      end
      chmod!(new_path, permissions)
      self.file = new_path
      self
    end

    def copy_to(new_path, permissions=nil, directory_permissions=nil)
      return if self.empty?
      new_path = File.expand_path(new_path)

      mkdir!(new_path, directory_permissions)
      if exists?
        FileUtils.cp(path, new_path) unless new_path == path
      else
        File.open(new_path, "wb") { |f| f.write(read) }
      end
      chmod!(new_path, permissions)
      self.class.new({:tempfile => new_path, :content_type => content_type})
    end

    def delete
      FileUtils.rm(self.path) if exists?
    end

    def to_file
      return @file if @file.is_a?(File)
      File.open(path, "rb") if exists?
    end

    def content_type
      return @content_type if @content_type
      if @file.respond_to?(:content_type) and @file.content_type
        @content_type = @file.content_type.to_s.chomp
      elsif path
        @content_type = ::MIME::Types.type_for(path).first.to_s
      end
    end

    def content_type=(type)
      @content_type = type
    end

    def sanitize_regexp
      CarrierWave::SanitizedFile.sanitize_regexp
    end

  private

    def file=(file)
      if file.is_a?(Hash)
        @file = file["tempfile"] || file[:tempfile]
        @original_filename = file["filename"] || file[:filename]
        @content_type = file["content_type"] || file[:content_type]
      else
        @file = file
        @original_filename = nil
        @content_type = nil
      end
    end

    def mkdir!(path, directory_permissions)
      options = {}
      options[:mode] = directory_permissions if directory_permissions
      FileUtils.mkdir_p(File.dirname(path), options) unless File.exists?(File.dirname(path))
    end

    def chmod!(path, permissions)
      File.chmod(permissions, path) if permissions
    end

    def sanitize(name)
      name = name.gsub("\\", "/") # work-around for IE
      name = File.basename(name)
      name = name.gsub(sanitize_regexp,"_")
      name = "_#{name}" if name =~ /\A\.+\z/
      name = "unnamed" if name.size == 0
      return name.mb_chars.to_s
    end

    def split_extension(filename)
      extension_matchers = [
        /\A(.+)\.(tar\.([glx]?z|bz2))\z/, # matches "something.tar.gz"
        /\A(.+)\.([^\.]+)\z/ # matches "something.jpg"
      ]

      extension_matchers.each do |regexp|
        if filename =~ regexp
          return $1, $2
        end
      end
      return filename, "" # In case we weren't able to split the extension
    end

  end # SanitizedFile
end # CarrierWave
