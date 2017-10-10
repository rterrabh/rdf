module ActiveRecord
  class Schema < Migration

    def migrations_paths
      ActiveRecord::Migrator.migrations_paths
    end

    def define(info, &block) # :nodoc:
      #nodyna <instance_eval-923> <IEV COMPLEX (block execution)>
      instance_eval(&block)

      unless info[:version].blank?
        initialize_schema_migrations_table
        connection.assume_migrated_upto_version(info[:version], migrations_paths)
      end
    end

    def self.define(info={}, &block)
      new.define(info, &block)
    end
  end
end
