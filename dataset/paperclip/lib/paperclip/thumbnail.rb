module Paperclip
  class Thumbnail < Processor

    attr_accessor :current_geometry, :target_geometry, :format, :whiny, :convert_options,
                  :source_file_options, :animated, :auto_orient

    ANIMATED_FORMATS = %w(gif)

    def initialize(file, options = {}, attachment = nil)
      super

      geometry             = options[:geometry].to_s
      @crop                = geometry[-1,1] == '#'
      @target_geometry     = options.fetch(:string_geometry_parser, Geometry).parse(geometry)
      @current_geometry    = options.fetch(:file_geometry_parser, Geometry).from_file(@file)
      @source_file_options = options[:source_file_options]
      @convert_options     = options[:convert_options]
      @whiny               = options.fetch(:whiny, true)
      @format              = options[:format]
      @animated            = options.fetch(:animated, true)
      @auto_orient         = options.fetch(:auto_orient, true)
      if @auto_orient && @current_geometry.respond_to?(:auto_orient)
        @current_geometry.auto_orient
      end

      @source_file_options = @source_file_options.split(/\s+/) if @source_file_options.respond_to?(:split)
      @convert_options     = @convert_options.split(/\s+/)     if @convert_options.respond_to?(:split)

      @current_format      = File.extname(@file.path)
      @basename            = File.basename(@file.path, @current_format)
    end

    def crop?
      @crop
    end

    def convert_options?
      !@convert_options.nil? && !@convert_options.empty?
    end

    def make
      src = @file
      filename = [@basename, @format ? ".#{@format}" : ""].join
      dst = TempfileFactory.new.generate(filename)

      begin
        parameters = []
        parameters << source_file_options
        parameters << ":source"
        parameters << transformation_command
        parameters << convert_options
        parameters << ":dest"

        parameters = parameters.flatten.compact.join(" ").strip.squeeze(" ")

        success = convert(parameters, :source => "#{File.expand_path(src.path)}#{'[0]' unless animated?}", :dest => File.expand_path(dst.path))
      rescue Cocaine::ExitStatusError => e
        raise Paperclip::Error, "There was an error processing the thumbnail for #{@basename}" if @whiny
      rescue Cocaine::CommandNotFoundError => e
        raise Paperclip::Errors::CommandNotFoundError.new("Could not run the `convert` command. Please install ImageMagick.")
      end

      dst
    end

    def transformation_command
      scale, crop = @current_geometry.transformation_to(@target_geometry, crop?)
      trans = []
      trans << "-coalesce" if animated?
      trans << "-auto-orient" if auto_orient
      trans << "-resize" << %["#{scale}"] unless scale.nil? || scale.empty?
      trans << "-crop" << %["#{crop}"] << "+repage" if crop
      trans << '-layers "optimize"' if animated?
      trans
    end

    protected

    def animated?
      @animated && (ANIMATED_FORMATS.include?(@format.to_s) || @format.blank?)  && identified_as_animated?
    end

    def identified_as_animated?
      if @identified_as_animated.nil?
        @identified_as_animated = ANIMATED_FORMATS.include? identify("-format %m :file", :file => "#{@file.path}[0]").to_s.downcase.strip
      end
      @identified_as_animated
    rescue Cocaine::ExitStatusError => e
      raise Paperclip::Error, "There was an error running `identify` for #{@basename}" if @whiny
    rescue Cocaine::CommandNotFoundError => e
      raise Paperclip::Errors::CommandNotFoundError.new("Could not run the `identify` command. Please install ImageMagick.")
    end
  end
end
