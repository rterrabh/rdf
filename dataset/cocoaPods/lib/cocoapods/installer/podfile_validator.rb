module Pod
  class Installer
    class PodfileValidator
      attr_reader :podfile

      attr_reader :errors

      def initialize(podfile)
        @podfile = podfile
        @errors = []
        @validated = false
      end

      def validate
        validate_pod_directives

        @validated = true
      end

      def valid?
        validate unless @validated

        @validated && errors.size == 0
      end

      def message
        errors.join("\n")
      end

      private

      def add_error(error)
        errors << error
      end

      def validate_pod_directives
        dependencies = podfile.target_definitions.flat_map do |_, target|
          target.dependencies
        end.uniq

        dependencies.each do |dependency|
          validate_conflicting_external_sources!(dependency)
        end
      end

      def validate_conflicting_external_sources!(dependency)
        external_source = dependency.external_source
        return false if external_source.nil?

        available_downloaders = Downloader.downloader_class_by_key.keys
        specified_downloaders = external_source.select { |key| available_downloaders.include?(key) }
        if specified_downloaders.size > 1
          add_error "The dependency `#{dependency.name}` specifies more than one download strategy(#{specified_downloaders.keys.join(',')})." \
            'Only one is allowed'
        end

        pod_spec_or_path = external_source[:podspec].present? || external_source[:path].present?
        if pod_spec_or_path && specified_downloaders.size > 0
          add_error "The dependency `#{dependency.name}` specifies `podspec` or `path` in combination with other" \
            ' download strategies. This is not allowed'
        end
      end
    end
  end
end
