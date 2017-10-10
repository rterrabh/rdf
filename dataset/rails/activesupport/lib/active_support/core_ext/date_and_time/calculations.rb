module DateAndTime
  module Calculations
    DAYS_INTO_WEEK = {
      :monday    => 0,
      :tuesday   => 1,
      :wednesday => 2,
      :thursday  => 3,
      :friday    => 4,
      :saturday  => 5,
      :sunday    => 6
    }

    def yesterday
      advance(:days => -1)
    end

    def tomorrow
      advance(:days => 1)
    end

    def today?
      to_date == ::Date.current
    end

    def past?
      self < self.class.current
    end

    def future?
      self > self.class.current
    end

    def days_ago(days)
      advance(:days => -days)
    end

    def days_since(days)
      advance(:days => days)
    end

    def weeks_ago(weeks)
      advance(:weeks => -weeks)
    end

    def weeks_since(weeks)
      advance(:weeks => weeks)
    end

    def months_ago(months)
      advance(:months => -months)
    end

    def months_since(months)
      advance(:months => months)
    end

    def years_ago(years)
      advance(:years => -years)
    end

    def years_since(years)
      advance(:years => years)
    end

    def beginning_of_month
      first_hour(change(:day => 1))
    end
    alias :at_beginning_of_month :beginning_of_month

    def beginning_of_quarter
      first_quarter_month = [10, 7, 4, 1].detect { |m| m <= month }
      beginning_of_month.change(:month => first_quarter_month)
    end
    alias :at_beginning_of_quarter :beginning_of_quarter

    def end_of_quarter
      last_quarter_month = [3, 6, 9, 12].detect { |m| m >= month }
      beginning_of_month.change(:month => last_quarter_month).end_of_month
    end
    alias :at_end_of_quarter :end_of_quarter

    def beginning_of_year
      change(:month => 1).beginning_of_month
    end
    alias :at_beginning_of_year :beginning_of_year

    def next_week(given_day_in_next_week = Date.beginning_of_week)
      first_hour(weeks_since(1).beginning_of_week.days_since(days_span(given_day_in_next_week)))
    end

    def next_month
      months_since(1)
    end

    def next_quarter
      months_since(3)
    end

    def next_year
      years_since(1)
    end

    def prev_week(start_day = Date.beginning_of_week)
      first_hour(weeks_ago(1).beginning_of_week.days_since(days_span(start_day)))
    end
    alias_method :last_week, :prev_week

    def prev_month
      months_ago(1)
    end
    alias_method :last_month, :prev_month

    def prev_quarter
      months_ago(3)
    end
    alias_method :last_quarter, :prev_quarter

    def prev_year
      years_ago(1)
    end
    alias_method :last_year, :prev_year

    def days_to_week_start(start_day = Date.beginning_of_week)
      start_day_number = DAYS_INTO_WEEK[start_day]
      current_day_number = wday != 0 ? wday - 1 : 6
      (current_day_number - start_day_number) % 7
    end

    def beginning_of_week(start_day = Date.beginning_of_week)
      result = days_ago(days_to_week_start(start_day))
      acts_like?(:time) ? result.midnight : result
    end
    alias :at_beginning_of_week :beginning_of_week

    def monday
      beginning_of_week(:monday)
    end

    def end_of_week(start_day = Date.beginning_of_week)
      last_hour(days_since(6 - days_to_week_start(start_day)))
    end
    alias :at_end_of_week :end_of_week

    def sunday
      end_of_week(:monday)
    end

    def end_of_month
      last_day = ::Time.days_in_month(month, year)
      last_hour(days_since(last_day - day))
    end
    alias :at_end_of_month :end_of_month

    def end_of_year
      change(:month => 12).end_of_month
    end
    alias :at_end_of_year :end_of_year

    def all_week(start_day = Date.beginning_of_week)
      beginning_of_week(start_day)..end_of_week(start_day)
    end

    def all_month
      beginning_of_month..end_of_month
    end

    def all_quarter
      beginning_of_quarter..end_of_quarter
    end

    def all_year
      beginning_of_year..end_of_year
    end

    private

    def first_hour(date_or_time)
      date_or_time.acts_like?(:time) ? date_or_time.beginning_of_day : date_or_time
    end

    def last_hour(date_or_time)
      date_or_time.acts_like?(:time) ? date_or_time.end_of_day : date_or_time
    end

    def days_span(day)
      (DAYS_INTO_WEEK[day] - DAYS_INTO_WEEK[Date.beginning_of_week]) % 7
    end
  end
end
