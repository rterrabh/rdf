require 'active_support/core_ext/hash/except'
require 'active_support/core_ext/hash/slice'

module ActiveModel
  module Serialization
    def serializable_hash(options = nil)
      options ||= {}

      attribute_names = attributes.keys
      if only = options[:only]
        attribute_names &= Array(only).map(&:to_s)
      elsif except = options[:except]
        attribute_names -= Array(except).map(&:to_s)
      end

      hash = {}
      attribute_names.each { |n| hash[n] = read_attribute_for_serialization(n) }

      #nodyna <send-958> <SD COMPLEX (array)>
      Array(options[:methods]).each { |m| hash[m.to_s] = send(m) if respond_to?(m) }

      serializable_add_includes(options) do |association, records, opts|
        hash[association.to_s] = if records.respond_to?(:to_ary)
          records.to_ary.map { |a| a.serializable_hash(opts) }
        else
          records.serializable_hash(opts)
        end
      end

      hash
    end

    private

      alias :read_attribute_for_serialization :send

      def serializable_add_includes(options = {}) #:nodoc:
        return unless includes = options[:include]

        unless includes.is_a?(Hash)
          includes = Hash[Array(includes).map { |n| n.is_a?(Hash) ? n.to_a.first : [n, {}] }]
        end

        includes.each do |association, opts|
          #nodyna <send-959> <SD COMPLEX (array)>
          if records = send(association)
            yield association, records, opts
          end
        end
      end
  end
end
