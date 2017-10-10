
require 'uri/generic'

module URI

  class MailTo < Generic
    include REGEXP

    DEFAULT_PORT = nil

    COMPONENT = [ :scheme, :to, :headers ].freeze


    HEADER_REGEXP  = /\A(?<hfield>(?:%\h\h|[!$'-.0-;@-Z_a-z~])*=(?:%\h\h|[!$'-.0-;@-Z_a-z~])*)(?:&\g<hfield>)*\z/
    EMAIL_REGEXP = /\A[a-zA-Z0-9.!\#$%&'*+\/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*\z/

    def self.build(args)
      tmp = Util::make_components_hash(self, args)

      case tmp[:to]
      when Array
        tmp[:opaque] = tmp[:to].join(',')
      when String
        tmp[:opaque] = tmp[:to].dup
      else
        tmp[:opaque] = ''
      end

      if tmp[:headers]
        query =
          case tmp[:headers]
          when Array
            tmp[:headers].collect { |x|
              if x.kind_of?(Array)
                x[0] + '=' + x[1..-1].join
              else
                x.to_s
              end
            }.join('&')
          when Hash
            tmp[:headers].collect { |h,v|
              h + '=' + v
            }.join('&')
          else
            tmp[:headers].to_s
          end
        unless query.empty?
          tmp[:opaque] << '?' << query
        end
      end

      return super(tmp)
    end

    def initialize(*arg)
      super(*arg)

      @to = nil
      @headers = []

      to, header = @opaque.split('?', 2)
      unless /\A(?:[^@,;]+@[^@,;]+(?:\z|[,;]))*\z/ =~ to
        raise InvalidComponentError,
          "unrecognised opaque part for mailtoURL: #{@opaque}"
      end

      if arg[10] # arg_check
        self.to = to
        self.headers = header
      else
        set_to(to)
        set_headers(header)
      end
    end

    attr_reader :to

    attr_reader :headers

    def check_to(v)
      return true unless v
      return true if v.size == 0

      v.split(/[,;]/).each do |addr|
        if /\A(?:%\h\h|[!$&-.0-;=@-Z_a-z~])*\z/ !~ addr
          raise InvalidComponentError,
            "an address in 'to' is invalid as URI #{addr.dump}"
        end

        addr.gsub!(/%\h\h/, URI::TBLDECWWWCOMP_)
        if EMAIL_REGEXP !~ addr
          raise InvalidComponentError,
            "an address in 'to' is invalid as uri-escaped addr-spec #{addr.dump}"
        end
      end

      return true
    end
    private :check_to

    def set_to(v)
      @to = v
    end
    protected :set_to

    def to=(v)
      check_to(v)
      set_to(v)
      v
    end

    def check_headers(v)
      return true unless v
      return true if v.size == 0
      if HEADER_REGEXP !~ v
        raise InvalidComponentError,
          "bad component(expected opaque component): #{v}"
      end

      return true
    end
    private :check_headers

    def set_headers(v)
      @headers = []
      if v
        v.split('&').each do |x|
          @headers << x.split(/=/, 2)
        end
      end
    end
    protected :set_headers

    def headers=(v)
      check_headers(v)
      set_headers(v)
      v
    end

    def to_s
      @scheme + ':' +
        if @to
          @to
        else
          ''
        end +
        if @headers.size > 0
          '?' + @headers.collect{|x| x.join('=')}.join('&')
        else
          ''
        end +
        if @fragment
          '#' + @fragment
        else
          ''
        end
    end

    def to_mailtext
      to = parser.unescape(@to)
      head = ''
      body = ''
      @headers.each do |x|
        case x[0]
        when 'body'
          body = parser.unescape(x[1])
        when 'to'
          to << ', ' + parser.unescape(x[1])
        else
          head << parser.unescape(x[0]).capitalize + ': ' +
            parser.unescape(x[1])  + "\n"
        end
      end

      return "To: #{to}
"
    end
    alias to_rfc822text to_mailtext
  end

  @@schemes['MAILTO'] = MailTo
end
