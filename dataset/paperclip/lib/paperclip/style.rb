module Paperclip

  class Style

    attr_reader :name, :attachment, :format

    def initialize name, definition, attachment
      @name = name
      @attachment = attachment
      if definition.is_a? Hash
        @geometry = definition.delete(:geometry)
        @format = definition.delete(:format)
        @processors = definition.delete(:processors)
        @convert_options = definition.delete(:convert_options)
        @source_file_options = definition.delete(:source_file_options)
        @other_args = definition
      elsif definition.is_a? String
        @geometry = definition
        @format = nil
        @other_args = {}
      else
        @geometry, @format = [definition, nil].flatten[0..1]
        @other_args = {}
      end
      @format = default_format if @format.blank?
    end

    def processors
      @processors.respond_to?(:call) ? @processors.call(attachment.instance) : (@processors || attachment.processors)
    end

    def whiny
      attachment.whiny
    end

    def whiny?
      !!whiny
    end

    def convert_options
      @convert_options.respond_to?(:call) ? @convert_options.call(attachment.instance) :
        #nodyna <send-744> <SD EASY (private methods)>
        (@convert_options || attachment.send(:extra_options_for, name))
    end

    def source_file_options
      @source_file_options.respond_to?(:call) ? @source_file_options.call(attachment.instance) :
        #nodyna <send-745> <SD EASY (private methods)>
        (@source_file_options || attachment.send(:extra_source_file_options_for, name))
    end

    def geometry
      @geometry.respond_to?(:call) ? @geometry.call(attachment.instance) : @geometry
    end

    def processor_options
      args = {:style => name}
      @other_args.each do |k,v|
        args[k] = v.respond_to?(:call) ? v.call(attachment) : v
      end
      [:processors, :geometry, :format, :whiny, :convert_options, :source_file_options].each do |k|
        #nodyna <send-746> <SD MODERATE (array)>
        (arg = send(k)) && args[k] = arg
      end
      args
    end

    def [](key)
      if [:name, :convert_options, :whiny, :processors, :geometry, :format, :animated, :source_file_options].include?(key)
        #nodyna <send-747> <SD MODERATE (array)>
        send(key)
      elsif defined? @other_args[key]
        @other_args[key]
      end
    end

    def []=(key, value)
      if [:name, :convert_options, :whiny, :processors, :geometry, :format, :animated, :source_file_options].include?(key)
        #nodyna <send-748> <SD MODERATE (array)>
        send("#{key}=".intern, value)
      else
        @other_args[key] = value
      end
    end

    def default_format
      base = attachment.options[:default_format]
      base.respond_to?(:call) ? base.call(attachment, name) : base
    end

  end
end
