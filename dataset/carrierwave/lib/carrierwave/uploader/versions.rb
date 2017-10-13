
module CarrierWave
  module Uploader
    module Versions
      extend ActiveSupport::Concern

      include CarrierWave::Uploader::Callbacks

      included do
        class_attribute :versions, :version_names, :instance_reader => false, :instance_writer => false

        self.versions = {}
        self.version_names = []

        attr_accessor :parent_cache_id

        after :cache, :assign_parent_cache_id
        after :cache, :cache_versions!
        after :store, :store_versions!
        after :remove, :remove_versions!
        after :retrieve_from_cache, :retrieve_versions_from_cache!
        after :retrieve_from_store, :retrieve_versions_from_store!
      end

      module ClassMethods

        def version(name, options = {}, &block)
          name = name.to_sym
          build_version(name, options) unless versions[name]

          #nodyna <class_eval-2678> <CE COMPLEX (block execution)>
          versions[name][:uploader].class_eval(&block) if block
          versions[name]
        end

        def recursively_apply_block_to_versions(&block)
          versions.each do |name, version|
            #nodyna <class_eval-2679> <CE COMPLEX (block execution)>
            version[:uploader].class_eval(&block)
            version[:uploader].recursively_apply_block_to_versions(&block)
          end
        end

      private

        def build_version(name, options)
          uploader = Class.new(self)
          #nodyna <const_set-2680> <CS COMPLEX (change-prone variable)>
          const_set("Uploader#{uploader.object_id}".gsub('-', '_'), uploader)
          uploader.version_names += [name]
          uploader.versions = {}
          uploader.processors = []

          #nodyna <class_eval-2681> <CE MODERATE (define methods)>
          uploader.class_eval <<-RUBY, __FILE__, __LINE__ + 1
            def self.enable_processing(value=nil)
              self.enable_processing = value if value
              if !@enable_processing.nil?
                @enable_processing
              else
                superclass.enable_processing
              end
            end

            def move_to_cache
              false
            end
          RUBY

          #nodyna <class_eval-2682> <CE COMPLEX (define methods)>
          class_eval <<-RUBY
            def #{name}
              versions[:#{name}]
            end
          RUBY

          current_version = {
            name => {
              :uploader => uploader,
              :options  => options
            }
          }
          self.versions = versions.merge(current_version)
        end

      end # ClassMethods

      def versions
        return @versions if @versions
        @versions = {}
        self.class.versions.each do |name, version|
          @versions[name] = version[:uploader].new(model, mounted_as)
        end
        @versions
      end

      def version_name
        self.class.version_names.join('_').to_sym unless self.class.version_names.blank?
      end

      def version_exists?(name)
        name = name.to_sym

        return false unless self.class.versions.has_key?(name)

        condition = self.class.versions[name][:options][:if]
        if(condition)
          if(condition.respond_to?(:call))
            condition.call(self, :version => name, :file => file)
          else
            #nodyna <send-2683> <SD COMPLEX (change-prone variable)>
            send(condition, file)
          end
        else
          true
        end
      end

      def url(*args)
        if (version = args.first) && version.respond_to?(:to_sym)
          raise ArgumentError, "Version #{version} doesn't exist!" if versions[version.to_sym].nil?
          versions[version.to_sym].url(*args[1..-1])
        elsif args.first
          super(args.first)
        else
          super
        end
      end

      def recreate_versions!(*versions)
        if versions.any?
          file = sanitized_file if !cached?
          store_versions!(file, versions)
        else
          cache! if !cached?
          store!
        end
      end

    private
      def assign_parent_cache_id(file)
        active_versions.each do |name, uploader|
          uploader.parent_cache_id = @cache_id
        end
      end

      def active_versions
        versions.select do |name, uploader|
          version_exists?(name)
        end
      end

      def full_filename(for_file)
        [version_name, super(for_file)].compact.join('_')
      end

      def full_original_filename
        [version_name, super].compact.join('_')
      end

      def cache_versions!(new_file)
        processed_parent = SanitizedFile.new :tempfile => self.file,
          :filename => new_file.original_filename

        active_versions.each do |name, v|
          next if v.cached?

          #nodyna <send-2684> <SD EASY (private access)>
          v.send(:cache_id=, cache_id)
          if self.class.versions[name][:options] && self.class.versions[name][:options][:from_version]
            unless versions[self.class.versions[name][:options][:from_version]].cached?
              versions[self.class.versions[name][:options][:from_version]].cache!(processed_parent)
            end
            processed_version = SanitizedFile.new :tempfile => versions[self.class.versions[name][:options][:from_version]],
              :filename => new_file.original_filename
            v.cache!(processed_version)
          else
            v.cache!(processed_parent)
          end
        end
      end

      def store_versions!(new_file, versions=nil)
        if versions
          active = Hash[active_versions]
          versions.each { |v| active[v].try(:store!, new_file) } unless active.empty?
        else
          active_versions.each { |name, v| v.store!(new_file) }
        end
      end

      def remove_versions!
        versions.each { |name, v| v.remove! }
      end

      def retrieve_versions_from_cache!(cache_name)
        versions.each { |name, v| v.retrieve_from_cache!(cache_name) }
      end

      def retrieve_versions_from_store!(identifier)
        versions.each { |name, v| v.retrieve_from_store!(identifier) }
      end

    end # Versions
  end # Uploader
end # CarrierWave
