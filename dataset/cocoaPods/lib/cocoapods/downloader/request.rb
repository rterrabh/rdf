require 'digest'

module Pod
  module Downloader
    class Request
      attr_reader :spec

      attr_reader :released_pod
      alias_method :released_pod?, :released_pod

      attr_reader :name

      attr_reader :params

      attr_reader :head
      alias_method :head?, :head

      def initialize(spec: nil, released: false, name: nil, params: false, head: false)
        @released_pod = released
        @spec = spec
        @params = spec ? (spec.source && spec.source.dup) : params
        @name = spec ? spec.name : name
        @head = head

        validate!
      end

      def slug(name: self.name, params: self.params, spec: self.spec)
        checksum = spec && spec.checksum &&  '-' << spec.checksum[0, 5]
        if released_pod?
          "Release/#{name}/#{spec.version}#{checksum}"
        else
          opts = params.to_a.sort_by(&:first).map { |k, v| "#{k}=#{v}" }.join('-')
          digest = Digest::MD5.hexdigest(opts)
          "External/#{name}/#{digest}#{checksum}"
        end
      end

      private

      def validate!
        raise ArgumentError, 'Requires a name' unless name
        raise ArgumentError, 'Must give a spec for a released download request' if released_pod? && !spec
        raise ArgumentError, 'Requires a version if released' if released_pod? && !spec.version
        raise ArgumentError, 'Requires params' unless params
      end
    end
  end
end
