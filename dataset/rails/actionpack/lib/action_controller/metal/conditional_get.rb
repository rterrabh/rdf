require 'active_support/core_ext/hash/keys'

module ActionController
  module ConditionalGet
    extend ActiveSupport::Concern

    include RackDelegation
    include Head

    included do
      class_attribute :etaggers
      self.etaggers = []
    end

    module ClassMethods
      def etag(&etagger)
        self.etaggers += [etagger]
      end
    end

    def fresh_when(record_or_options, additional_options = {})
      if record_or_options.is_a? Hash
        options = record_or_options
        options.assert_valid_keys(:etag, :last_modified, :public, :template)
      else
        record  = record_or_options
        options = { etag: record, last_modified: record.try(:updated_at) }.merge!(additional_options)
      end

      response.etag          = combine_etags(options)   if options[:etag] || options[:template]
      response.last_modified = options[:last_modified]  if options[:last_modified]
      response.cache_control[:public] = true            if options[:public]

      head :not_modified if request.fresh?(response)
    end

    def stale?(record_or_options, additional_options = {})
      fresh_when(record_or_options, additional_options)
      !request.fresh?(response)
    end

    def expires_in(seconds, options = {})
      response.cache_control.merge!(
        :max_age         => seconds,
        :public          => options.delete(:public),
        :must_revalidate => options.delete(:must_revalidate)
      )
      options.delete(:private)

      response.cache_control[:extras] = options.map {|k,v| "#{k}=#{v}"}
      response.date = Time.now unless response.date?
    end

    def expires_now
      response.cache_control.replace(:no_cache => true)
    end

    private
      def combine_etags(options)
        #nodyna <instance_exec-1304> <IEX COMPLEX (block with parameters)>
        etags = etaggers.map { |etagger| instance_exec(options, &etagger) }.compact
        etags.unshift options[:etag]
      end
  end
end
