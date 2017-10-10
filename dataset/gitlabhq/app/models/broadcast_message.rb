
class BroadcastMessage < ActiveRecord::Base
  include Sortable

  validates :message, presence: true
  validates :starts_at, presence: true
  validates :ends_at, presence: true

  validates :color, format: { with: /\A\#[0-9A-Fa-f]{3}{1,2}+\Z/ }, allow_blank: true
  validates :font,  format: { with: /\A\#[0-9A-Fa-f]{3}{1,2}+\Z/ }, allow_blank: true

  def self.current
    where("ends_at > :now AND starts_at < :now", now: Time.zone.now).last
  end
end
