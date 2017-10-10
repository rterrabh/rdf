module Paperclip
  module Helpers
    def configure
      yield(self) if block_given?
    end

    def interpolates key, &block
      Paperclip::Interpolations[key] = block
    end

    def run(cmd, arguments = "", interpolation_values = {}, local_options = {})
      command_path = options[:command_path]
      Cocaine::CommandLine.path = [Cocaine::CommandLine.path, command_path].flatten.compact.uniq
      if logging? && (options[:log_command] || local_options[:log_command])
        local_options = local_options.merge(:logger => logger)
      end
      Cocaine::CommandLine.new(cmd, arguments, local_options).run(interpolation_values)
    end

    def each_instance_with_attachment(klass, name)
      class_for(klass).unscoped.where("#{name}_file_name IS NOT NULL").find_each do |instance|
        yield(instance)
      end
    end

    def class_for(class_name)
      class_name.split('::').inject(Object) do |klass, partial_class_name|
        if klass.const_defined?(partial_class_name)
          #nodyna <const_get-749> <CG COMPLEX (array)>
          klass.const_get(partial_class_name, false)
        else
          klass.const_missing(partial_class_name)
        end
      end
    end

    def reset_duplicate_clash_check!
      @names_url = nil
    end
  end
end
