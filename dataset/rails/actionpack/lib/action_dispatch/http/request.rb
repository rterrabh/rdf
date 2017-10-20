require 'stringio'

require 'active_support/inflector'
require 'action_dispatch/http/headers'
require 'action_controller/metal/exceptions'
require 'rack/request'
require 'action_dispatch/http/cache'
require 'action_dispatch/http/mime_negotiation'
require 'action_dispatch/http/parameters'
require 'action_dispatch/http/filter_parameters'
require 'action_dispatch/http/upload'
require 'action_dispatch/http/url'
require 'active_support/core_ext/array/conversions'

module ActionDispatch
  class Request < Rack::Request
    include ActionDispatch::Http::Cache::Request
    include ActionDispatch::Http::MimeNegotiation
    include ActionDispatch::Http::Parameters
    include ActionDispatch::Http::FilterParameters
    include ActionDispatch::Http::URL

    autoload :Session, 'action_dispatch/request/session'
    autoload :Utils,   'action_dispatch/request/utils'

    LOCALHOST   = Regexp.union [/^127\.\d{1,3}\.\d{1,3}\.\d{1,3}$/, /^::1$/, /^0:0:0:0:0:0:0:1(%.*)?$/]

    ENV_METHODS = %w[ AUTH_TYPE GATEWAY_INTERFACE
        PATH_TRANSLATED REMOTE_HOST
        REMOTE_IDENT REMOTE_USER REMOTE_ADDR
        SERVER_NAME SERVER_PROTOCOL

        HTTP_ACCEPT HTTP_ACCEPT_CHARSET HTTP_ACCEPT_ENCODING
        HTTP_ACCEPT_LANGUAGE HTTP_CACHE_CONTROL HTTP_FROM
        HTTP_NEGOTIATE HTTP_PRAGMA ].freeze

    ENV_METHODS.each do |env|
      #nodyna <class_eval-1238> <CE MODERATE (define methods)>
      class_eval <<-METHOD, __FILE__, __LINE__ + 1
        def #{env.sub(/^HTTP_/n, '').downcase}  # def accept_charset
          @env["#{env}"]                        #   @env["HTTP_ACCEPT_CHARSET"]
        end                                     # end
      METHOD
    end

    def initialize(env)
      super
      @method            = nil
      @request_method    = nil
      @remote_ip         = nil
      @original_fullpath = nil
      @fullpath          = nil
      @ip                = nil
      @uuid              = nil
    end

    def check_path_parameters!
      path_parameters.each do |key, value|
        next unless value.respond_to?(:valid_encoding?)
        unless value.valid_encoding?
          raise ActionController::BadRequest, "Invalid parameter: #{key} => #{value}"
        end
      end
    end

    def key?(key)
      @env.key?(key)
    end

    RFC2616 = %w(OPTIONS GET HEAD POST PUT DELETE TRACE CONNECT)
    RFC2518 = %w(PROPFIND PROPPATCH MKCOL COPY MOVE LOCK UNLOCK)
    RFC3253 = %w(VERSION-CONTROL REPORT CHECKOUT CHECKIN UNCHECKOUT MKWORKSPACE UPDATE LABEL MERGE BASELINE-CONTROL MKACTIVITY)
    RFC3648 = %w(ORDERPATCH)
    RFC3744 = %w(ACL)
    RFC5323 = %w(SEARCH)
    RFC4791 = %w(MKCALENDAR)
    RFC5789 = %w(PATCH)

    HTTP_METHODS = RFC2616 + RFC2518 + RFC3253 + RFC3648 + RFC3744 + RFC5323 + RFC4791 + RFC5789

    HTTP_METHOD_LOOKUP = {}

    HTTP_METHODS.each { |method|
      HTTP_METHOD_LOOKUP[method] = method.underscore.to_sym
    }

    def request_method
      @request_method ||= check_method(env["REQUEST_METHOD"])
    end

    def request_method=(request_method) #:nodoc:
      if check_method(request_method)
        @request_method = env["REQUEST_METHOD"] = request_method
      end
    end

    def request_method_symbol
      HTTP_METHOD_LOOKUP[request_method]
    end

    def method
      @method ||= check_method(env["rack.methodoverride.original_method"] || env['REQUEST_METHOD'])
    end

    def method_symbol
      HTTP_METHOD_LOOKUP[method]
    end

    def get?
      HTTP_METHOD_LOOKUP[request_method] == :get
    end

    def post?
      HTTP_METHOD_LOOKUP[request_method] == :post
    end

    def patch?
      HTTP_METHOD_LOOKUP[request_method] == :patch
    end

    def put?
      HTTP_METHOD_LOOKUP[request_method] == :put
    end

    def delete?
      HTTP_METHOD_LOOKUP[request_method] == :delete
    end

    def head?
      HTTP_METHOD_LOOKUP[request_method] == :head
    end

    def headers
      Http::Headers.new(@env)
    end

    def original_fullpath
      @original_fullpath ||= (env["ORIGINAL_FULLPATH"] || fullpath)
    end

    def fullpath
      @fullpath ||= super
    end

    def original_url
      base_url + original_fullpath
    end

    def media_type
      content_mime_type.to_s
    end

    def content_length
      super.to_i
    end

    def xml_http_request?
      @env['HTTP_X_REQUESTED_WITH'] =~ /XMLHttpRequest/i
    end
    alias :xhr? :xml_http_request?

    def ip
      @ip ||= super
    end

    def remote_ip
      @remote_ip ||= (@env["action_dispatch.remote_ip"] || ip).to_s
    end

    def uuid
      @uuid ||= env["action_dispatch.request_id"]
    end

    def server_software
      (@env['SERVER_SOFTWARE'] && /^([a-zA-Z]+)/ =~ @env['SERVER_SOFTWARE']) ? $1.downcase : nil
    end

    def raw_post
      unless @env.include? 'RAW_POST_DATA'
        raw_post_body = body
        @env['RAW_POST_DATA'] = raw_post_body.read(content_length)
        raw_post_body.rewind if raw_post_body.respond_to?(:rewind)
      end
      @env['RAW_POST_DATA']
    end

    def body
      if raw_post = @env['RAW_POST_DATA']
        raw_post.force_encoding(Encoding::BINARY)
        StringIO.new(raw_post)
      else
        @env['rack.input']
      end
    end

    def form_data?
      FORM_DATA_MEDIA_TYPES.include?(content_mime_type.to_s)
    end

    def body_stream #:nodoc:
      @env['rack.input']
    end

    def reset_session
      if session && session.respond_to?(:destroy)
        session.destroy
      else
        self.session = {}
      end
      @env['action_dispatch.request.flash_hash'] = nil
    end

    def session=(session) #:nodoc:
      Session.set @env, session
    end

    def session_options=(options)
      Session::Options.set @env, options
    end

    def GET
      @env["action_dispatch.request.query_parameters"] ||= Utils.deep_munge(normalize_encode_params(super || {}))
    rescue Rack::Utils::ParameterTypeError, Rack::Utils::InvalidParameterError => e
      raise ActionController::BadRequest.new(:query, e)
    end
    alias :query_parameters :GET

    def POST
      @env["action_dispatch.request.request_parameters"] ||= Utils.deep_munge(normalize_encode_params(super || {}))
    rescue Rack::Utils::ParameterTypeError, Rack::Utils::InvalidParameterError => e
      raise ActionController::BadRequest.new(:request, e)
    end
    alias :request_parameters :POST

    def authorization
      @env['HTTP_AUTHORIZATION']   ||
      @env['X-HTTP_AUTHORIZATION'] ||
      @env['X_HTTP_AUTHORIZATION'] ||
      @env['REDIRECT_X_HTTP_AUTHORIZATION']
    end

    def local?
      LOCALHOST =~ remote_addr && LOCALHOST =~ remote_ip
    end

    def deep_munge(hash)
      ActiveSupport::Deprecation.warn(
        'This method has been extracted into `ActionDispatch::Request::Utils.deep_munge`. Please start using that instead.'
      )

      Utils.deep_munge(hash)
    end

    protected
      def parse_query(qs)
        Utils.deep_munge(super)
      end

    private
      def check_method(name)
        HTTP_METHOD_LOOKUP[name] || raise(ActionController::UnknownHttpMethod, "#{name}, accepted HTTP methods are #{HTTP_METHODS[0...-1].join(', ')}, and #{HTTP_METHODS[-1]}")
        name
      end
  end
end
