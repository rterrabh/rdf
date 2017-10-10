class Module
  def deprecate(*method_names)
    ActiveSupport::Deprecation.deprecate_methods(self, *method_names)
  end
end
