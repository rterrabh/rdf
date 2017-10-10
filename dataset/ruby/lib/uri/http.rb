
require 'uri/generic'

module URI

  class HTTP < Generic
    DEFAULT_PORT = 80

    COMPONENT = [
      :scheme,
      :userinfo, :host, :port,
      :path,
      :query,
      :fragment
    ].freeze

    def self.build(args)
      tmp = Util::make_components_hash(self, args)
      return super(tmp)
    end

    def initialize(*arg)
      super(*arg)
    end

    def request_uri
      return nil unless @path
      if @path.start_with?(?/.freeze)
        @query ? "#@path?#@query" : @path.dup
      else
        @query ? "/#@path?#@query" : "/#@path"
      end
    end
  end

  @@schemes['HTTP'] = HTTP
end
