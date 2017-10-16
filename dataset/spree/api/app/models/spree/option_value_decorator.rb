#nodyna <class_eval-2405> <CE MODERATE (define methods)>
Spree::OptionValue.class_eval do
  def option_type_name
    option_type.name
  end

  def option_type_presentation
    option_type.presentation
  end
end
