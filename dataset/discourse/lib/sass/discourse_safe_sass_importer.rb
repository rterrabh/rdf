require_dependency 'sass/discourse_sass_importer'


class DiscourseSafeSassImporter < DiscourseSassImporter
  def special_imports
    super.merge({
      "plugins" => [],
      "plugins_mobile" => [],
      "plugins_desktop" => [],
      "plugins_variables" => []
    })
  end

  def find(name, options)
    if name == "theme_variables"
      contents = ""
      special_imports[name].each do |css_file|
        contents << File.read(css_file)
      end
      Sass::Engine.new(contents, options.merge(
        filename: "#{name}.scss",
        importer: self,
        syntax: :scss
      ))
    else
      super(name, options)
    end
  end
end
