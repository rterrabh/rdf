require 'active_support/string_inquirer'

class String
  def inquiry
    ActiveSupport::StringInquirer.new(self)
  end
end
