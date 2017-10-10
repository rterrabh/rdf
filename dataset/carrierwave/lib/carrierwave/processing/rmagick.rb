
module CarrierWave

  module RMagick
    extend ActiveSupport::Concern

    included do
      begin
        require "RMagick"
      rescue LoadError => e
        e.message << " (You may need to install the rmagick gem)"
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

      def resize_to_fill(width, height, gravity=::Magick::CenterGravity)
        process :resize_to_fill => [width, height, gravity]
      end

      def resize_and_pad(width, height, background=:transparent, gravity=::Magick::CenterGravity)
        process :resize_and_pad => [width, height, background, gravity]
      end

      def resize_to_geometry_string(geometry_string)
        process :resize_to_geometry_string => [geometry_string]
      end
    end

    def convert(format)
      manipulate!(:format => format)
      @format = format
    end

    def resize_to_limit(width, height)
      manipulate! do |img|
        geometry = Magick::Geometry.new(width, height, 0, 0, Magick::GreaterGeometry)
        new_img = img.change_geometry(geometry) do |new_width, new_height|
          img.resize(new_width, new_height)
        end
        destroy_image(img)
        new_img = yield(new_img) if block_given?
        new_img
      end
    end

    def resize_to_fit(width, height)
      manipulate! do |img|
        img.resize_to_fit!(width, height)
        img = yield(img) if block_given?
        img
      end
    end

    def resize_to_fill(width, height, gravity=::Magick::CenterGravity)
      manipulate! do |img|
        img.crop_resized!(width, height, gravity)
        img = yield(img) if block_given?
        img
      end
    end

    def resize_and_pad(width, height, background=:transparent, gravity=::Magick::CenterGravity)
      manipulate! do |img|
        img.resize_to_fit!(width, height)
        new_img = ::Magick::Image.new(width, height) { self.background_color = background == :transparent ? 'rgba(255,255,255,0)' : background.to_s }
        if background == :transparent
          filled = new_img.matte_floodfill(1, 1)
        else
          filled = new_img.color_floodfill(1, 1, ::Magick::Pixel.from_color(background))
        end
        destroy_image(new_img)
        filled.composite!(img, gravity, ::Magick::OverCompositeOp)
        destroy_image(img)
        filled = yield(filled) if block_given?
        filled
      end
    end

    def resize_to_geometry_string(geometry_string)
      manipulate! do |img|
        new_img = img.change_geometry(geometry_string) do |new_width, new_height|
          img.resize(new_width, new_height)
        end
        destroy_image(img)
        new_img = yield(new_img) if block_given?
        new_img
      end
    end

    def manipulate!(options={}, &block)
      cache_stored_file! if !cached?

      read_block = create_info_block(options[:read])
      image = ::Magick::Image.read(current_path, &read_block)
      frames = ::Magick::ImageList.new

      image.each_with_index do |frame, index|
        frame = yield *[frame, index, options].take(block.arity) if block_given?
        frames << frame if frame
      end
      frames.append(true) if block_given?

      write_block = create_info_block(options[:write])
      if options[:format] || @format
        frames.write("#{options[:format] || @format}:#{current_path}", &write_block)
      else
        frames.write(current_path, &write_block)
      end
      destroy_image(frames)
    rescue ::Magick::ImageMagickError => e
      raise CarrierWave::ProcessingError, I18n.translate(:"errors.messages.rmagick_processing_error", :e => e, :default => I18n.translate(:"errors.messages.rmagick_processing_error", :e => e, :locale => :en))
    end

  private

    def create_info_block(options)
      return nil unless options
      assignments = options.map { |k, v| "self.#{k} = #{v}" }
      code = "lambda { |img| " + assignments.join(";") + "}"
      #nodyna <eval-2664> <not yet classified>
      eval code
    end

    def destroy_image(image)
      image.destroy! if image.respond_to?(:destroy!)
    end

  end # RMagick
end # CarrierWave
