class EmailLog < ActiveRecord::Base
  belongs_to :user
  belongs_to :post
  belongs_to :topic

  validates :email_type, :to_address, presence: true

  scope :sent,    -> { where(skipped: false) }
  scope :skipped, -> { where(skipped: true) }

  after_create do
    # Update last_emailed_at if the user_id is present and email was sent
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

# == Schema Information
#
# Table name: email_logs
#
#  id             :integer          not null, primary key
#  to_address     :string(255)      not null
#  email_type     :string(255)      not null
#  user_id        :integer
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  reply_key      :string(32)
#  post_id        :integer
#  topic_id       :integer
#  skipped        :boolean          default(FALSE)
#  skipped_reason :string(255)
#
# Indexes
#
#  index_email_logs_on_created_at              (created_at)
#  index_email_logs_on_reply_key               (reply_key)
#  index_email_logs_on_skipped_and_created_at  (skipped,created_at)
#  index_email_logs_on_user_id_and_created_at  (user_id,created_at)
#
