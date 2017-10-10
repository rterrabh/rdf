require 'benchmark'
require 'abstract_controller/logger'

module ActionController
  module Instrumentation
    extend ActiveSupport::Concern

    include AbstractController::Logger
    include ActionController::RackDelegation

    attr_internal :view_runtime

    def process_action(*args)
      raw_payload = {
        :controller => self.class.name,
        :action     => self.action_name,
        :params     => request.filtered_parameters,
        :format     => request.format.try(:ref),
        :method     => request.request_method,
        :path       => (request.fullpath rescue "unknown")
      }

      ActiveSupport::Notifications.instrument("start_processing.action_controller", raw_payload.dup)

      ActiveSupport::Notifications.instrument("process_action.action_controller", raw_payload) do |payload|
        begin
          result = super
          payload[:status] = response.status
          result
        ensure
          append_info_to_payload(payload)
        end
      end
    end

    def render(*args)
      render_output = nil
      self.view_runtime = cleanup_view_runtime do
        Benchmark.ms { render_output = super }
      end
      render_output
    end

    def send_file(path, options={})
      ActiveSupport::Notifications.instrument("send_file.action_controller",
        options.merge(:path => path)) do
        super
      end
    end

    def send_data(data, options = {})
      ActiveSupport::Notifications.instrument("send_data.action_controller", options) do
        super
      end
    end

    def redirect_to(*args)
      ActiveSupport::Notifications.instrument("redirect_to.action_controller") do |payload|
        result = super
        payload[:status]   = response.status
        payload[:location] = response.filtered_location
        result
      end
    end

  private

    def halted_callback_hook(filter)
      ActiveSupport::Notifications.instrument("halted_callback.action_controller", :filter => filter)
    end

    def cleanup_view_runtime #:nodoc:
      yield
    end

    def append_info_to_payload(payload) #:nodoc:
      payload[:view_runtime] = view_runtime
    end

    module ClassMethods
      def log_process_action(payload) #:nodoc:
        messages, view_runtime = [], payload[:view_runtime]
        messages << ("Views: %.1fms" % view_runtime.to_f) if view_runtime
        messages
      end
    end
  end
end
