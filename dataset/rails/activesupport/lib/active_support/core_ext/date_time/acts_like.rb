require 'date'
require 'active_support/core_ext/object/acts_like'

class DateTime
  def acts_like_date?
    true
  end

  def acts_like_time?
    true
  end
end
