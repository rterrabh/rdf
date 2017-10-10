class EmailLog < ActiveRecord::Base
  belongs_to :user
  belongs_to :post
  belongs_to :topic

  validates :email_type, :to_address, presence: true

  scope :sent,    -> { where(skipped: false) }
  scope :skipped, -> { where(skipped: true) }

  after_create do
    User.where(id: user_id).update_all("last_emailed_at = CURRENT_TIMESTAMP") if user_id.present? and !skipped
  end

  def self.count_per_day(start_date, end_date)
    where('created_at >= ? and created_at < ? AND skipped = false', start_date, end_date).group('date(created_at)').order('date(created_at)').count
  end

  def self.for(reply_key)
    EmailLog.find_by(reply_key: reply_key)
  end

  def self.last_sent_email_address
    where(email_type: 'signup').order('created_at DESC').first.try(:to_address)
  end

end

