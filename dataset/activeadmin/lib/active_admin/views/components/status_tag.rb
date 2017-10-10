module ActiveAdmin
  module Views
    class StatusTag < ActiveAdmin::Component
      builder_method :status_tag

      def tag_name
        'span'
      end

      def default_class_name
        'status_tag'
      end

      def build(*args)
        options = args.extract_options!
        status = args[0]
        type = args[1]
        label = options.delete(:label)
        classes = options.delete(:class)
        status = convert_to_boolean_status(status)

        if status
          content = label || if s = status.to_s and s.present?
            I18n.t "active_admin.status_tag.#{s.downcase}", default: s.titleize
          end
        end

        super(content, options)

        add_class(status_to_class(status)) if status
        add_class(type.to_s) if type
        add_class(classes) if classes
      end

      protected

      def convert_to_boolean_status(status)
        if status == 'true'
          'Yes'
        elsif ['false', nil].include?(status)
          'No'
        else
          status
        end
      end

      def status_to_class(status)
        case status
        when String, Symbol
          status.to_s.titleize.gsub(/\s/, '').underscore
        else
          ''
        end
      end
    end
  end
end
