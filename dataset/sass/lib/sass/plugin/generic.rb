
unless defined?(Sass::GENERIC_LOADED)
  Sass::GENERIC_LOADED = true

  Sass::Plugin.options.merge!(:css_location   => './public/stylesheets',
                              :always_update  => false,
                              :always_check   => true)
end
