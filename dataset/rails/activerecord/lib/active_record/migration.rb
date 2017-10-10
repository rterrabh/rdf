require "active_support/core_ext/module/attribute_accessors"
require 'set'

module ActiveRecord
  class MigrationError < ActiveRecordError#:nodoc:
    def initialize(message = nil)
      message = "\n\n#{message}\n\n" if message
      super
    end
  end

  class IrreversibleMigration < MigrationError
  end

  class DuplicateMigrationVersionError < MigrationError#:nodoc:
    def initialize(version)
      super("Multiple migrations have the version number #{version}")
    end
  end

  class DuplicateMigrationNameError < MigrationError#:nodoc:
    def initialize(name)
      super("Multiple migrations have the name #{name}")
    end
  end

  class UnknownMigrationVersionError < MigrationError #:nodoc:
    def initialize(version)
      super("No migration with version number #{version}")
    end
  end

  class IllegalMigrationNameError < MigrationError#:nodoc:
    def initialize(name)
      super("Illegal name for migration file: #{name}\n\t(only lower case letters, numbers, and '_' allowed)")
    end
  end

  class PendingMigrationError < MigrationError#:nodoc:
    def initialize
      if defined?(Rails.env)
        super("Migrations are pending. To resolve this issue, run:\n\n\tbin/rake db:migrate RAILS_ENV=#{::Rails.env}")
      else
        super("Migrations are pending. To resolve this issue, run:\n\n\tbin/rake db:migrate")
      end
    end
  end

  class Migration
    autoload :CommandRecorder, 'active_record/migration/command_recorder'


    class CheckPending
      def initialize(app)
        @app = app
        @last_check = 0
      end

      def call(env)
        if connection.supports_migrations?
          mtime = ActiveRecord::Migrator.last_migration.mtime.to_i
          if @last_check < mtime
            ActiveRecord::Migration.check_pending!(connection)
            @last_check = mtime
          end
        end
        @app.call(env)
      end

      private

      def connection
        ActiveRecord::Base.connection
      end
    end

    class << self
      attr_accessor :delegate # :nodoc:
      attr_accessor :disable_ddl_transaction # :nodoc:

      def check_pending!(connection = Base.connection)
        raise ActiveRecord::PendingMigrationError if ActiveRecord::Migrator.needs_migration?(connection)
      end

      def load_schema_if_pending!
        if ActiveRecord::Migrator.needs_migration? || !ActiveRecord::Migrator.any_migrations?
          FileUtils.cd Rails.root do
            current_config = Base.connection_config
            Base.clear_all_connections!
            system("bin/rake db:test:prepare")
            Base.establish_connection(current_config)
          end
          check_pending!
        end
      end

      def maintain_test_schema! # :nodoc:
        if ActiveRecord::Base.maintain_test_schema
          suppress_messages { load_schema_if_pending! }
        end
      end

      def method_missing(name, *args, &block) # :nodoc:
        #nodyna <send-846> <SD COMPLEX (change-prone variables)>
        (delegate || superclass.delegate).send(name, *args, &block)
      end

      def migrate(direction)
        new.migrate direction
      end

      def disable_ddl_transaction!
        @disable_ddl_transaction = true
      end
    end

    def disable_ddl_transaction # :nodoc:
      self.class.disable_ddl_transaction
    end

    cattr_accessor :verbose
    attr_accessor :name, :version

    def initialize(name = self.class.name, version = nil)
      @name       = name
      @version    = version
      @connection = nil
    end

    self.verbose = true
    self.delegate = new

    def revert(*migration_classes)
      run(*migration_classes.reverse, revert: true) unless migration_classes.empty?
      if block_given?
        if @connection.respond_to? :revert
          @connection.revert { yield }
        else
          recorder = CommandRecorder.new(@connection)
          @connection = recorder
          suppress_messages do
            @connection.revert { yield }
          end
          @connection = recorder.delegate
          recorder.commands.each do |cmd, args, block|
            #nodyna <send-847> <SD COMPLEX (array)>
            send(cmd, *args, &block)
          end
        end
      end
    end

    def reverting?
      @connection.respond_to?(:reverting) && @connection.reverting
    end

    class ReversibleBlockHelper < Struct.new(:reverting) # :nodoc:
      def up
        yield unless reverting
      end

      def down
        yield if reverting
      end
    end

    def reversible
      helper = ReversibleBlockHelper.new(reverting?)
      execute_block{ yield helper }
    end

    def run(*migration_classes)
      opts = migration_classes.extract_options!
      dir = opts[:direction] || :up
      dir = (dir == :down ? :up : :down) if opts[:revert]
      if reverting?
        revert { run(*migration_classes, direction: dir, revert: true) }
      else
        migration_classes.each do |migration_class|
          migration_class.new.exec_migration(@connection, dir)
        end
      end
    end

    def up
      self.class.delegate = self
      return unless self.class.respond_to?(:up)
      self.class.up
    end

    def down
      self.class.delegate = self
      return unless self.class.respond_to?(:down)
      self.class.down
    end

    def migrate(direction)
      return unless respond_to?(direction)

      case direction
      when :up   then announce "migrating"
      when :down then announce "reverting"
      end

      time   = nil
      ActiveRecord::Base.connection_pool.with_connection do |conn|
        time = Benchmark.measure do
          exec_migration(conn, direction)
        end
      end

      case direction
      when :up   then announce "migrated (%.4fs)" % time.real; write
      when :down then announce "reverted (%.4fs)" % time.real; write
      end
    end

    def exec_migration(conn, direction)
      @connection = conn
      if respond_to?(:change)
        if direction == :down
          revert { change }
        else
          change
        end
      else
        #nodyna <send-848> <SD COMPLEX (change-prone variables)>
        send(direction)
      end
    ensure
      @connection = nil
    end

    def write(text="")
      puts(text) if verbose
    end

    def announce(message)
      text = "#{version} #{name}: #{message}"
      length = [0, 75 - text.length].max
      write "== %s %s" % [text, "=" * length]
    end

    def say(message, subitem=false)
      write "#{subitem ? "   ->" : "--"} #{message}"
    end

    def say_with_time(message)
      say(message)
      result = nil
      time = Benchmark.measure { result = yield }
      say "%.4fs" % time.real, :subitem
      say("#{result} rows", :subitem) if result.is_a?(Integer)
      result
    end

    def suppress_messages
      save, self.verbose = verbose, false
      yield
    ensure
      self.verbose = save
    end

    def connection
      @connection || ActiveRecord::Base.connection
    end

    def method_missing(method, *arguments, &block)
      arg_list = arguments.map{ |a| a.inspect } * ', '

      say_with_time "#{method}(#{arg_list})" do
        unless @connection.respond_to? :revert
          unless arguments.empty? || [:execute, :enable_extension, :disable_extension].include?(method)
            arguments[0] = proper_table_name(arguments.first, table_name_options)
            if [:rename_table, :add_foreign_key].include?(method) ||
              (method == :remove_foreign_key && !arguments.second.is_a?(Hash))
              arguments[1] = proper_table_name(arguments.second, table_name_options)
            end
          end
        end
        return super unless connection.respond_to?(method)
        #nodyna <send-849> <SD COMPLEX (change-prone variables)>
        connection.send(method, *arguments, &block)
      end
    end

    def copy(destination, sources, options = {})
      copied = []

      FileUtils.mkdir_p(destination) unless File.exist?(destination)

      destination_migrations = ActiveRecord::Migrator.migrations(destination)
      last = destination_migrations.last
      sources.each do |scope, path|
        source_migrations = ActiveRecord::Migrator.migrations(path)

        source_migrations.each do |migration|
          source = File.binread(migration.filename)
          inserted_comment = "# This migration comes from #{scope} (originally #{migration.version})\n"
          if /\A#.*\b(?:en)?coding:\s*\S+/ =~ source
            source[/\n/] = "\n#{inserted_comment}"
          else
            source = "#{inserted_comment}#{source}"
          end

          if duplicate = destination_migrations.detect { |m| m.name == migration.name }
            if options[:on_skip] && duplicate.scope != scope.to_s
              options[:on_skip].call(scope, migration)
            end
            next
          end

          migration.version = next_migration_number(last ? last.version + 1 : 0).to_i
          new_path = File.join(destination, "#{migration.version}_#{migration.name.underscore}.#{scope}.rb")
          old_path, migration.filename = migration.filename, new_path
          last = migration

          File.binwrite(migration.filename, source)
          copied << migration
          options[:on_copy].call(scope, migration, old_path) if options[:on_copy]
          destination_migrations << migration
        end
      end

      copied
    end

    def proper_table_name(name, options = {})
      if name.respond_to? :table_name
        name.table_name
      else
        "#{options[:table_name_prefix]}#{name}#{options[:table_name_suffix]}"
      end
    end

    def next_migration_number(number)
      if ActiveRecord::Base.timestamped_migrations
        [Time.now.utc.strftime("%Y%m%d%H%M%S"), "%.14d" % number].max
      else
        SchemaMigration.normalize_migration_number(number)
      end
    end

    def table_name_options(config = ActiveRecord::Base)
      {
        table_name_prefix: config.table_name_prefix,
        table_name_suffix: config.table_name_suffix
      }
    end

    private
    def execute_block
      if connection.respond_to? :execute_block
        super # use normal delegation to record the block
      else
        yield
      end
    end
  end

  class MigrationProxy < Struct.new(:name, :version, :filename, :scope)

    def initialize(name, version, filename, scope)
      super
      @migration = nil
    end

    def basename
      File.basename(filename)
    end

    def mtime
      File.mtime filename
    end

    delegate :migrate, :announce, :write, :disable_ddl_transaction, to: :migration

    private

      def migration
        @migration ||= load_migration
      end

      def load_migration
        require(File.expand_path(filename))
        name.constantize.new(name, version)
      end

  end

  class NullMigration < MigrationProxy #:nodoc:
    def initialize
      super(nil, 0, nil, nil)
    end

    def mtime
      0
    end
  end

  class Migrator#:nodoc:
    class << self
      attr_writer :migrations_paths
      alias :migrations_path= :migrations_paths=

      def migrate(migrations_paths, target_version = nil, &block)
        case
        when target_version.nil?
          up(migrations_paths, target_version, &block)
        when current_version == 0 && target_version == 0
          []
        when current_version > target_version
          down(migrations_paths, target_version, &block)
        else
          up(migrations_paths, target_version, &block)
        end
      end

      def rollback(migrations_paths, steps=1)
        move(:down, migrations_paths, steps)
      end

      def forward(migrations_paths, steps=1)
        move(:up, migrations_paths, steps)
      end

      def up(migrations_paths, target_version = nil)
        migrations = migrations(migrations_paths)
        migrations.select! { |m| yield m } if block_given?

        new(:up, migrations, target_version).migrate
      end

      def down(migrations_paths, target_version = nil, &block)
        migrations = migrations(migrations_paths)
        migrations.select! { |m| yield m } if block_given?

        new(:down, migrations, target_version).migrate
      end

      def run(direction, migrations_paths, target_version)
        new(direction, migrations(migrations_paths), target_version).run
      end

      def open(migrations_paths)
        new(:up, migrations(migrations_paths), nil)
      end

      def schema_migrations_table_name
        SchemaMigration.table_name
      end

      def get_all_versions(connection = Base.connection)
        if connection.table_exists?(schema_migrations_table_name)
          SchemaMigration.all.map { |x| x.version.to_i }.sort
        else
          []
        end
      end

      def current_version(connection = Base.connection)
        get_all_versions(connection).max || 0
      end

      def needs_migration?(connection = Base.connection)
        (migrations(migrations_paths).collect(&:version) - get_all_versions(connection)).size > 0
      end

      def any_migrations?
        migrations(migrations_paths).any?
      end

      def last_version
        last_migration.version
      end

      def last_migration #:nodoc:
        migrations(migrations_paths).last || NullMigration.new
      end

      def migrations_paths
        @migrations_paths ||= ['db/migrate']
        Array(@migrations_paths)
      end

      def migrations_path
        migrations_paths.first
      end

      def migrations(paths)
        paths = Array(paths)

        files = Dir[*paths.map { |p| "#{p}/**/[0-9]*_*.rb" }]

        migrations = files.map do |file|
          version, name, scope = file.scan(/([0-9]+)_([_a-z0-9]*)\.?([_a-z0-9]*)?\.rb\z/).first

          raise IllegalMigrationNameError.new(file) unless version
          version = version.to_i
          name = name.camelize

          MigrationProxy.new(name, version, file, scope)
        end

        migrations.sort_by(&:version)
      end

      private

      def move(direction, migrations_paths, steps)
        migrator = new(direction, migrations(migrations_paths))
        start_index = migrator.migrations.index(migrator.current_migration)

        if start_index
          finish = migrator.migrations[start_index + steps]
          version = finish ? finish.version : 0
          #nodyna <send-850> <SD MODERATE (change-prone variables)>
          send(direction, migrations_paths, version)
        end
      end
    end

    def initialize(direction, migrations, target_version = nil)
      raise StandardError.new("This database does not yet support migrations") unless Base.connection.supports_migrations?

      @direction         = direction
      @target_version    = target_version
      @migrated_versions = nil
      @migrations        = migrations

      validate(@migrations)

      Base.connection.initialize_schema_migrations_table
    end

    def current_version
      migrated.max || 0
    end

    def current_migration
      migrations.detect { |m| m.version == current_version }
    end
    alias :current :current_migration

    def run
      migration = migrations.detect { |m| m.version == @target_version }
      raise UnknownMigrationVersionError.new(@target_version) if migration.nil?
      unless (up? && migrated.include?(migration.version.to_i)) || (down? && !migrated.include?(migration.version.to_i))
        begin
          execute_migration_in_transaction(migration, @direction)
        rescue => e
          canceled_msg = use_transaction?(migration) ? ", this migration was canceled" : ""
          raise StandardError, "An error has occurred#{canceled_msg}:\n\n#{e}", e.backtrace
        end
      end
    end

    def migrate
      if !target && @target_version && @target_version > 0
        raise UnknownMigrationVersionError.new(@target_version)
      end

      runnable.each do |migration|
        Base.logger.info "Migrating to #{migration.name} (#{migration.version})" if Base.logger

        begin
          execute_migration_in_transaction(migration, @direction)
        rescue => e
          canceled_msg = use_transaction?(migration) ? "this and " : ""
          raise StandardError, "An error has occurred, #{canceled_msg}all later migrations canceled:\n\n#{e}", e.backtrace
        end
      end
    end

    def runnable
      runnable = migrations[start..finish]
      if up?
        runnable.reject { |m| ran?(m) }
      else
        runnable.pop if target
        runnable.find_all { |m| ran?(m) }
      end
    end

    def migrations
      down? ? @migrations.reverse : @migrations.sort_by(&:version)
    end

    def pending_migrations
      already_migrated = migrated
      migrations.reject { |m| already_migrated.include?(m.version) }
    end

    def migrated
      @migrated_versions ||= Set.new(self.class.get_all_versions)
    end

    private
    def ran?(migration)
      migrated.include?(migration.version.to_i)
    end

    def execute_migration_in_transaction(migration, direction)
      ddl_transaction(migration) do
        migration.migrate(direction)
        record_version_state_after_migrating(migration.version)
      end
    end

    def target
      migrations.detect { |m| m.version == @target_version }
    end

    def finish
      migrations.index(target) || migrations.size - 1
    end

    def start
      up? ? 0 : (migrations.index(current) || 0)
    end

    def validate(migrations)
      name ,= migrations.group_by(&:name).find { |_,v| v.length > 1 }
      raise DuplicateMigrationNameError.new(name) if name

      version ,= migrations.group_by(&:version).find { |_,v| v.length > 1 }
      raise DuplicateMigrationVersionError.new(version) if version
    end

    def record_version_state_after_migrating(version)
      if down?
        migrated.delete(version)
        ActiveRecord::SchemaMigration.where(:version => version.to_s).delete_all
      else
        migrated << version
        ActiveRecord::SchemaMigration.create!(:version => version.to_s)
      end
    end

    def up?
      @direction == :up
    end

    def down?
      @direction == :down
    end

    def ddl_transaction(migration)
      if use_transaction?(migration)
        Base.transaction { yield }
      else
        yield
      end
    end

    def use_transaction?(migration)
      !migration.disable_ddl_transaction && Base.connection.supports_ddl_transactions?
    end
  end
end
