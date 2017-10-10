
module CarrierWave

  module MiniMagick
    extend ActiveSupport::Concern

    included do
      begin
        require "mini_magick"
      rescue LoadError => e
        e.message << " (You may need to install the mini_magick gem)"
        raise e
      end
    end

    module ClassMethods
      def convert(format)
        process :convert => format
      end

      def resize_to_limit(width, height)
        process :resize_to_limit => [width, height]
      end

      def resize_to_fit(width, height)
        process :resize_to_fit => [width, height]
      end

      def resize_to_fill(width, height, gravity='Center')
        process :resize_to_fill => [width, height, gravity]
      end

      def resize_and_pad(width, height, background=:transparent, gravity=::Magick::CenterGravity)
        process :resize_and_pad => [width, height, background, gravity]
      end
    end

    def convert(format)
      @format = format
      manipulate! do |img|
        img.format(format.to_s.downcase)
        img = yield(img) if block_given?
        img
      end
    end

    def resize_to_limit(width, height)
      manipulate! do |img|
        img.resize "#{width}x#{height}>"
        img = yield(img) if block_given?
        img
      end
    end

    def resize_to_fit(width, height)
      manipulate! do |img|
        img.resize "#{width}x#{height}"
        img = yield(img) if block_given?
        img
      end
    end

    def resize_to_fill(width, height, gravity = 'Center')
      manipulate! do |img|
        cols, rows = img[:dimensions]
        img.combine_options do |cmd|
          if width != cols || height != rows
            scale_x = width/cols.to_f
            scale_y = height/rows.to_f
            if scale_x >= scale_y
              cols = (scale_x * (cols + 0.5)).round
              rows = (scale_x * (rows + 0.5)).round
              cmd.resize "#{cols}"
            else
              cols = (scale_y * (cols + 0.5)).round
              rows = (scale_y * (rows + 0.5)).round
              cmd.resize "x#{rows}"
            end
          end
          cmd.gravity gravity
          cmd.background "rgba(255,255,255,0.0)"
          cmd.extent "#{width}x#{height}" if cols != width || rows != height
        end
        img = yield(img) if block_given?
        img
      end
    end

    def resize_and_pad(width, height, background=:transparent, gravity='Center')
      manipulate! do |img|
        img.combine_options do |cmd|
          cmd.thumbnail "#{width}x#{height}>"
          if background == :transparent
            cmd.background "rgba(255, 255, 255, 0.0)"
          else
            cmd.background background
          end
          cmd.gravity gravity
          cmd.extent "#{width}x#{height}"
        end
        img = yield(img) if block_given?
        img
      end
    end

    def manipulate!
      cache_stored_file! if !cached?
      image = ::MiniMagick::Image.open(current_path)

      begin
        image.format(@format.to_s.downcase) if @format
        image = yield(image)
        image.write(current_path)
        image.run_command("identify", current_path)
      ensure
        image.destroy!
      end
    rescue ::MiniMagick::Error, ::MiniMagick::Invalid => e
      default = I18n.translate(:"errors.messages.mini_magick_processing_error", :e => e, :locale => :en)
      message = I18n.translate(:"errors.messages.mini_magick_processing_error", :e => e, :default => default)
      raise CarrierWave::ProcessingError, message
    end

  end # MiniMagick
end # CarrierWave
