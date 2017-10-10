require 'action_view/helpers/javascript_helper'
require 'active_support/core_ext/array/access'
require 'active_support/core_ext/hash/keys'
require 'active_support/core_ext/string/output_safety'

module ActionView
  module Helpers #:nodoc:
    module UrlHelper
      BUTTON_TAG_METHOD_VERBS = %w{patch put delete}
      extend ActiveSupport::Concern

      include TagHelper

      module ClassMethods
        def _url_for_modules
          ActionView::RoutingUrlFor
        end
      end

      def url_for(options = nil) # :nodoc:
        case options
        when String
          options
        when :back
          _back_url
        else
          raise ArgumentError, "arguments passed to url_for can't be handled. Please require " +
                               "routes or provide your own implementation"
        end
      end

      def _back_url # :nodoc:
        referrer = controller.respond_to?(:request) && controller.request.env["HTTP_REFERER"]
        referrer || 'javascript:history.back()'
      end
      protected :_back_url

      def link_to(name = nil, options = nil, html_options = nil, &block)
        html_options, options, name = options, name, block if block_given?
        options ||= {}

        html_options = convert_options_to_data_attributes(options, html_options)

        url = url_for(options)
        html_options['href'] ||= url

        content_tag(:a, name || url, html_options, &block)
      end

      def button_to(name = nil, options = nil, html_options = nil, &block)
        html_options, options = options, name if block_given?
        options      ||= {}
        html_options ||= {}

        html_options = html_options.stringify_keys
        convert_boolean_attributes!(html_options, %w(disabled))

        url    = options.is_a?(String) ? options : url_for(options)
        remote = html_options.delete('remote')
        params = html_options.delete('params')

        method     = html_options.delete('method').to_s
        method_tag = BUTTON_TAG_METHOD_VERBS.include?(method) ? method_tag(method) : ''.html_safe

        form_method  = method == 'get' ? 'get' : 'post'
        form_options = html_options.delete('form') || {}
        form_options[:class] ||= html_options.delete('form_class') || 'button_to'
        form_options.merge!(method: form_method, action: url)
        form_options.merge!("data-remote" => "true") if remote

        request_token_tag = form_method == 'post' ? token_tag : ''

        html_options = convert_options_to_data_attributes(options, html_options)
        html_options['type'] = 'submit'

        button = if block_given?
          content_tag('button', html_options, &block)
        else
          html_options['value'] = name || url
          tag('input', html_options)
        end

        inner_tags = method_tag.safe_concat(button).safe_concat(request_token_tag)
        if params
          params.each do |param_name, value|
            inner_tags.safe_concat tag(:input, type: "hidden", name: param_name, value: value.to_param)
          end
        end
        content_tag('form', inner_tags, form_options)
      end

      def link_to_unless_current(name, options = {}, html_options = {}, &block)
        link_to_unless current_page?(options), name, options, html_options, &block
      end

      def link_to_unless(condition, name, options = {}, html_options = {}, &block)
        link_to_if !condition, name, options, html_options, &block
      end

      def link_to_if(condition, name, options = {}, html_options = {}, &block)
        if condition
          link_to(name, options, html_options)
        else
          if block_given?
            block.arity <= 1 ? capture(name, &block) : capture(name, options, html_options, &block)
          else
            ERB::Util.html_escape(name)
          end
        end
      end

      def mail_to(email_address, name = nil, html_options = {}, &block)
        html_options, name = name, nil if block_given?
        html_options = (html_options || {}).stringify_keys

        extras = %w{ cc bcc body subject }.map! { |item|
          option = html_options.delete(item) || next
          "#{item}=#{Rack::Utils.escape_path(option)}"
        }.compact
        extras = extras.empty? ? '' : '?' + extras.join('&')

        encoded_email_address = ERB::Util.url_encode(email_address).gsub("%40", "@")
        html_options["href"] = "mailto:#{encoded_email_address}#{extras}"

        content_tag(:a, name || email_address, html_options, &block)
      end

      def current_page?(options)
        unless request
          raise "You cannot use helpers that need to determine the current " \
                "page unless your view context provides a Request object " \
                "in a #request method"
        end

        return false unless request.get? || request.head?

        url_string = URI.parser.unescape(url_for(options)).force_encoding(Encoding::BINARY)

        request_uri = url_string.index("?") ? request.fullpath : request.path
        request_uri = URI.parser.unescape(request_uri).force_encoding(Encoding::BINARY)

        if url_string =~ /^\w+:\/\//
          url_string == "#{request.protocol}#{request.host_with_port}#{request_uri}"
        else
          url_string == request_uri
        end
      end

      private
        def convert_options_to_data_attributes(options, html_options)
          if html_options
            html_options = html_options.stringify_keys
            html_options['data-remote'] = 'true' if link_to_remote_options?(options) || link_to_remote_options?(html_options)

            method  = html_options.delete('method')

            add_method_to_attributes!(html_options, method) if method

            html_options
          else
            link_to_remote_options?(options) ? {'data-remote' => 'true'} : {}
          end
        end

        def link_to_remote_options?(options)
          if options.is_a?(Hash)
            options.delete('remote') || options.delete(:remote)
          end
        end

        def add_method_to_attributes!(html_options, method)
          if method && method.to_s.downcase != "get" && html_options["rel"] !~ /nofollow/
            html_options["rel"] = "#{html_options["rel"]} nofollow".lstrip
          end
          html_options["data-method"] = method
        end

        def convert_boolean_attributes!(html_options, bool_attrs)
          bool_attrs.each { |x| html_options[x] = x if html_options.delete(x) }
          html_options
        end

        def token_tag(token=nil)
          if token != false && protect_against_forgery?
            token ||= form_authenticity_token
            tag(:input, type: "hidden", name: request_forgery_protection_token.to_s, value: token)
          else
            ''
          end
        end

        def method_tag(method)
          tag('input', type: 'hidden', name: '_method', value: method.to_s)
        end
    end
  end
end
