module Gitlab
  module Themes
    APPLICATION_DEFAULT = 2

    Theme = Struct.new(:id, :name, :css_class)

    THEMES = [
      Theme.new(1, 'Graphite', 'ui_graphite'),
      Theme.new(2, 'Charcoal', 'ui_charcoal'),
      Theme.new(3, 'Green',    'ui_green'),
      Theme.new(4, 'Gray',     'ui_gray'),
      Theme.new(5, 'Violet',   'ui_violet'),
      Theme.new(6, 'Blue',     'ui_blue')
    ].freeze

    def self.body_classes
      THEMES.collect(&:css_class).uniq.join(' ')
    end

    def self.by_id(id)
      THEMES.detect { |t| t.id == id } || default
    end

    def self.default
      by_id(default_id)
    end

    def self.each(&block)
      THEMES.each(&block)
    end

    private

    def self.default_id
      id = Gitlab.config.gitlab.default_theme.to_i

      if id < THEMES.first.id || id > THEMES.last.id
        APPLICATION_DEFAULT
      else
        id
      end
    end
  end
end
