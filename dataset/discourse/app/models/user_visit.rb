class UserVisit < ActiveRecord::Base

  def self.counts_by_day_query(start_date, end_date)
    where('visited_at >= ? and visited_at <= ?', start_date.to_date, end_date.to_date).group(:visited_at).order(:visited_at)
  end

  def self.by_day(start_date, end_date)
    counts_by_day_query(start_date, end_date).count
  end

  def self.mobile_by_day(start_date, end_date)
    counts_by_day_query(start_date, end_date).where(mobile: true).count
  end

  def self.ensure_consistency!
    exec_sql <<SQL
    UPDATE user_stats u set days_visited =
    (
      SELECT COUNT(*) FROM user_visits v WHERE v.user_id = u.user_id
    )
    WHERE days_visited <>
    (
      SELECT COUNT(*) FROM user_visits v WHERE v.user_id = u.user_id
    )
SQL
  end
end

