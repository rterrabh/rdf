module ActionController
  module Helpers
    extend ActiveSupport::Concern

    class << self; attr_accessor :helpers_path; end
    include AbstractController::Helpers

    included do
      class_attribute :helpers_path, :include_all_helpers
      self.helpers_path ||= []
      self.include_all_helpers = true
    end

    module ClassMethods
      def helper_attr(*attrs)
        attrs.flatten.each { |attr| helper_method(attr, "#{attr}=") }
      end

      def helpers
        @helper_proxy ||= begin 
          proxy = ActionView::Base.new
          proxy.config = config.inheritable_copy
          proxy.extend(_helpers)
        end
      end

      def modules_for_helpers(args)
        args += all_application_helpers if args.delete(:all)
        super(args)
      end

      def all_helpers_from_path(path)
        helpers = Array(path).flat_map do |_path|
          extract = /^#{Regexp.quote(_path.to_s)}\/?(.*)_helper.rb$/
          names = Dir["#{_path}/**/*_helper.rb"].map { |file| file.sub(extract, '\1') }
          names.sort!
        end
        helpers.uniq!
        helpers
      end

      private
      def all_application_helpers
        all_helpers_from_path(helpers_path)
      end
    end
  end
end
