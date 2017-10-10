require 'active_support/descendants_tracker'

module ActionMailer
  module Previews #:nodoc:
    extend ActiveSupport::Concern

    included do
      mattr_accessor :preview_path, instance_writer: false

      mattr_accessor :show_previews, instance_writer: false

      mattr_accessor :preview_interceptors, instance_writer: false
      self.preview_interceptors = []
    end

    module ClassMethods
      def register_preview_interceptors(*interceptors)
        interceptors.flatten.compact.each { |interceptor| register_preview_interceptor(interceptor) }
      end

      def register_preview_interceptor(interceptor)
        preview_interceptor = case interceptor
          when String, Symbol
            interceptor.to_s.camelize.constantize
          else
            interceptor
          end

        unless preview_interceptors.include?(preview_interceptor)
          preview_interceptors << preview_interceptor
        end
      end
    end
  end

  class Preview
    extend ActiveSupport::DescendantsTracker

    class << self
      def all
        load_previews if descendants.empty?
        descendants
      end

      def call(email)
        preview = self.new
        #nodyna <send-1189> <SD COMPLEX (change-prone variables)>
        message = preview.public_send(email)
        inform_preview_interceptors(message)
        message
      end

      def emails
        public_instance_methods(false).map(&:to_s).sort
      end

      def email_exists?(email)
        emails.include?(email)
      end

      def exists?(preview)
        all.any?{ |p| p.preview_name == preview }
      end

      def find(preview)
        all.find{ |p| p.preview_name == preview }
      end

      def preview_name
        name.sub(/Preview$/, '').underscore
      end

      protected
        def load_previews #:nodoc:
          if preview_path
            Dir["#{preview_path}/**/*_preview.rb"].each{ |file| require_dependency file }
          end
        end

        def preview_path #:nodoc:
          Base.preview_path
        end

        def show_previews #:nodoc:
          Base.show_previews
        end

        def inform_preview_interceptors(message) #:nodoc:
          Base.preview_interceptors.each do |interceptor|
            interceptor.previewing_email(message)
          end
        end
    end
  end
end
