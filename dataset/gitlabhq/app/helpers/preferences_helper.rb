module PreferencesHelper
  COLOR_SCHEMES = {
    1 => 'white',
    2 => 'dark',
    3 => 'solarized-light',
    4 => 'solarized-dark',
    5 => 'monokai',
  }
  COLOR_SCHEMES.default = 'white'

  def color_schemes
    COLOR_SCHEMES.freeze
  end

  DASHBOARD_CHOICES = {
    projects: 'Your Projects (default)',
    stars:    'Starred Projects'
  }.with_indifferent_access.freeze

  def dashboard_choices
    defined = User.dashboards

    if defined.size != DASHBOARD_CHOICES.size
      raise RuntimeError, "`User` defines #{defined.size} dashboard choices," +
        " but `DASHBOARD_CHOICES` defined #{DASHBOARD_CHOICES.size}."
    else
      defined.map do |key, _|
        [DASHBOARD_CHOICES.fetch(key), key]
      end
    end
  end

  def project_view_choices
    [
      ['Readme (default)', :readme],
      ['Activity view', :activity]
    ]
  end

  def user_application_theme
    theme = Gitlab::Themes.by_id(current_user.try(:theme_id))
    theme.css_class
  end

  def user_color_scheme_class
    COLOR_SCHEMES[current_user.try(:color_scheme_id)] if defined?(current_user)
  end

  def prefer_readme?
    !current_user ||
      current_user.project_view == 'readme'
  end
end
