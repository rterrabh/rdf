module ActiveRecord
  module Associations
    class Preloader #:nodoc:
      extend ActiveSupport::Autoload

      eager_autoload do
        autoload :Association,           'active_record/associations/preloader/association'
        autoload :SingularAssociation,   'active_record/associations/preloader/singular_association'
        autoload :CollectionAssociation, 'active_record/associations/preloader/collection_association'
        autoload :ThroughAssociation,    'active_record/associations/preloader/through_association'

        autoload :HasMany,             'active_record/associations/preloader/has_many'
        autoload :HasManyThrough,      'active_record/associations/preloader/has_many_through'
        autoload :HasOne,              'active_record/associations/preloader/has_one'
        autoload :HasOneThrough,       'active_record/associations/preloader/has_one_through'
        autoload :BelongsTo,           'active_record/associations/preloader/belongs_to'
      end


      NULL_RELATION = Struct.new(:values, :bind_values).new({}, [])

      def preload(records, associations, preload_scope = nil)
        records       = Array.wrap(records).compact.uniq
        associations  = Array.wrap(associations)
        preload_scope = preload_scope || NULL_RELATION

        if records.empty?
          []
        else
          associations.flat_map { |association|
            preloaders_on association, records, preload_scope
          }
        end
      end

      private

      def preloaders_on(association, records, scope)
        case association
        when Hash
          preloaders_for_hash(association, records, scope)
        when Symbol
          preloaders_for_one(association, records, scope)
        when String
          preloaders_for_one(association.to_sym, records, scope)
        else
          raise ArgumentError, "#{association.inspect} was not recognised for preload"
        end
      end

      def preloaders_for_hash(association, records, scope)
        association.flat_map { |parent, child|
          loaders = preloaders_for_one parent, records, scope

          recs = loaders.flat_map(&:preloaded_records).uniq
          loaders.concat Array.wrap(child).flat_map { |assoc|
            preloaders_on assoc, recs, scope
          }
          loaders
        }
      end

      def preloaders_for_one(association, records, scope)
        grouped_records(association, records).flat_map do |reflection, klasses|
          klasses.map do |rhs_klass, rs|
            loader = preloader_for(reflection, rs, rhs_klass).new(rhs_klass, rs, reflection, scope)
            loader.run self
            loader
          end
        end
      end

      def grouped_records(association, records)
        h = {}
        records.each do |record|
          next unless record
          assoc = record.association(association)
          klasses = h[assoc.reflection] ||= {}
          (klasses[assoc.klass] ||= []) << record
        end
        h
      end

      class AlreadyLoaded # :nodoc:
        attr_reader :owners, :reflection

        def initialize(klass, owners, reflection, preload_scope)
          @owners = owners
          @reflection = reflection
        end

        def run(preloader); end

        def preloaded_records
          owners.flat_map { |owner| owner.association(reflection.name).target }
        end
      end

      class NullPreloader # :nodoc:
        def self.new(klass, owners, reflection, preload_scope); self; end
        def self.run(preloader); end
        def self.preloaded_records; []; end
      end

      def preloader_for(reflection, owners, rhs_klass)
        return NullPreloader unless rhs_klass

        if owners.first.association(reflection.name).loaded?
          return AlreadyLoaded
        end
        reflection.check_preloadable!

        case reflection.macro
        when :has_many
          reflection.options[:through] ? HasManyThrough : HasMany
        when :has_one
          reflection.options[:through] ? HasOneThrough : HasOne
        when :belongs_to
          BelongsTo
        end
      end
    end
  end
end
