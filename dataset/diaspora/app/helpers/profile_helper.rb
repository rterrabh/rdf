
module ProfileHelper
  def upper_limit_date_of_birth
    minimum_year = AppConfig.settings.terms.minimum_age.get
    minimum_year = minimum_year ?  minimum_year.to_i : 13
    minimum_year.years.ago.year
  end

  def lower_limit_date_of_birth
    125.years.ago.year
  end
end
