require 'active_support/per_thread_registry'

module ActiveRecord
  class RuntimeRegistry # :nodoc:
    extend ActiveSupport::PerThreadRegistry

    attr_accessor :connection_handler, :sql_runtime, :connection_id

    [:connection_handler, :sql_runtime, :connection_id].each do |val|
      #nodyna <class_eval-766> <not yet classified>
      class_eval %{ def self.#{val}; instance.#{val}; end }, __FILE__, __LINE__
      #nodyna <class_eval-767> <not yet classified>
      class_eval %{ def self.#{val}=(x); instance.#{val}=x; end }, __FILE__, __LINE__
    end
  end
end
