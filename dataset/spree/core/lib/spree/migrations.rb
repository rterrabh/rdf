module Spree
  class Migrations
    attr_reader :config, :engine_name

    def initialize(config, engine_name)
      @config, @engine_name = config, engine_name
    end

    def check
      if File.exists?("config/spree.yml") && File.directory?("db/migrate")
        engine_in_app = app_migrations.map do |file_name|
          name, engine = file_name.split(".", 2)
          next unless match_engine?(engine)
          name
        end.compact! || []

        missing_migrations = engine_migrations.sort - engine_in_app.sort
        unless missing_migrations.empty?
          puts "[#{engine_name.capitalize} WARNING] Missing migrations."
          missing_migrations.each do |migration|
            puts "[#{engine_name.capitalize} WARNING] #{migration} from #{engine_name} is missing."
          end
          puts "[#{engine_name.capitalize} WARNING] Run `bundle exec rake railties:install:migrations` to get them.\n\n"
          true
        end
      end
    end

    private
      def engine_migrations
        Dir.entries("#{config.root}/db/migrate").map do |file_name|
          name = file_name.split("_", 2).last.split(".", 2).first
          name.empty? ? next : name
        end.compact! || []
      end

      def app_migrations
        Dir.entries("db/migrate").map do |file_name|
          next if [".", ".."].include? file_name
          name = file_name.split("_", 2).last
          name.empty? ? next : name
        end.compact! || []
      end

      def match_engine?(engine)
        if engine_name == "spree"
          ["spree.rb", "spree_promo.rb"].include? engine
        else
          engine == "#{engine_name}.rb"
        end
      end
  end
end
