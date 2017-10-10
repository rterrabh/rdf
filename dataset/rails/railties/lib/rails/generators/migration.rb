require 'active_support/concern'
require 'rails/generators/actions/create_migration'

module Rails
  module Generators
    module Migration
      extend ActiveSupport::Concern
      attr_reader :migration_number, :migration_file_name, :migration_class_name

      module ClassMethods
        def migration_lookup_at(dirname) #:nodoc:
          Dir.glob("#{dirname}/[0-9]*_*.rb")
        end

        def migration_exists?(dirname, file_name) #:nodoc:
          migration_lookup_at(dirname).grep(/\d+_#{file_name}.rb$/).first
        end

        def current_migration_number(dirname) #:nodoc:
          migration_lookup_at(dirname).collect do |file|
            File.basename(file).split("_").first.to_i
          end.max.to_i
        end

        def next_migration_number(dirname) #:nodoc:
          raise NotImplementedError
        end
      end

      def create_migration(destination, data, config = {}, &block)
        action Rails::Generators::Actions::CreateMigration.new(self, destination, block || data.to_s, config)
      end

      def set_migration_assigns!(destination)
        destination = File.expand_path(destination, self.destination_root)

        migration_dir = File.dirname(destination)
        @migration_number     = self.class.next_migration_number(migration_dir)
        @migration_file_name  = File.basename(destination, '.rb')
        @migration_class_name = @migration_file_name.camelize
      end

      def migration_template(source, destination, config = {})
        source  = File.expand_path(find_in_source_paths(source.to_s))

        set_migration_assigns!(destination)
        #nodyna <instance_eval-1163> <IEV MODERATE (private access)>
        context = instance_eval('binding')

        dir, base = File.split(destination)
        numbered_destination = File.join(dir, ["%migration_number%", base].join('_'))

        create_migration numbered_destination, nil, config do
          ERB.new(::File.binread(source), nil, '-', '@output_buffer').result(context)
        end
      end
    end
  end
end
