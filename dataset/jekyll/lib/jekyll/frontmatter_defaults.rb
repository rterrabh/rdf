module Jekyll
  class FrontmatterDefaults
    def initialize(site)
      @site = site
    end

    def update_deprecated_types(set)
      return set unless set.key?('scope') && set['scope'].key?('type')

      set['scope']['type'] = case set['scope']['type']
      when 'page'
        Deprecator.defaults_deprecate_type('page', 'pages')
        'pages'
      when 'post'
        Deprecator.defaults_deprecate_type('post', 'posts')
        'posts'
      when 'draft'
        Deprecator.defaults_deprecate_type('draft', 'drafts')
        'drafts'
      else
        set['scope']['type']
      end

      set
    end

    def find(path, type, setting)
      value = nil
      old_scope = nil

      matching_sets(path, type).each do |set|
        if set['values'].key?(setting) && has_precedence?(old_scope, set['scope'])
          value = set['values'][setting]
          old_scope = set['scope']
        end
      end
      value
    end

    def all(path, type)
      defaults = {}
      old_scope = nil
      matching_sets(path, type).each do |set|
        if has_precedence?(old_scope, set['scope'])
          defaults = Utils.deep_merge_hashes(defaults, set['values'])
          old_scope = set['scope']
        else
          defaults = Utils.deep_merge_hashes(set['values'], defaults)
        end
      end
      defaults
    end

    private

    def applies?(scope, path, type)
      applies_path?(scope, path) && applies_type?(scope, type)
    end

    def applies_path?(scope, path)
      return true if !scope.has_key?('path') || scope['path'].empty?

      scope_path = Pathname.new(scope['path'])
      Pathname.new(sanitize_path(path)).ascend do |path|
        if path == scope_path
          return true
        end
      end
    end

    def applies_type?(scope, type)
      !scope.key?('type') || scope['type'].eql?(type.to_s)
    end

    def valid?(set)
      set.is_a?(Hash) && set['values'].is_a?(Hash)
    end

    def has_precedence?(old_scope, new_scope)
      return true if old_scope.nil?

      new_path = sanitize_path(new_scope['path'])
      old_path = sanitize_path(old_scope['path'])

      if new_path.length != old_path.length
        new_path.length >= old_path.length
      elsif new_scope.key? 'type'
        true
      else
        !old_scope.key? 'type'
      end
    end

    def matching_sets(path, type)
      valid_sets.select do |set|
        !set.has_key?('scope') || applies?(set['scope'], path, type)
      end
    end

    def valid_sets
      sets = @site.config['defaults']
      return [] unless sets.is_a?(Array)

      sets.map do |set|
        if valid?(set)
          update_deprecated_types(set)
        else
          Jekyll.logger.warn "Defaults:", "An invalid front-matter default set was found:"
          Jekyll.logger.warn "#{set}"
          nil
        end
      end.compact
    end

    def sanitize_path(path)
      if path.nil? || path.empty?
        ""
      else
        path.gsub(/\A\//, '').gsub(/([^\/])\z/, '\1')
      end
    end
  end
end
