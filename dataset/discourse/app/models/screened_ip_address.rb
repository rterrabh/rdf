require_dependency 'screening_model'
require_dependency 'ip_addr'

class ScreenedIpAddress < ActiveRecord::Base

  include ScreeningModel

  default_action :block

  validates :ip_address, ip_address_format: true, presence: true

  def self.watch(ip_address, opts={})
    match_for_ip_address(ip_address) || create(opts.slice(:action_type).merge(ip_address: ip_address))
  end

  def ip_address=(val)
    if val.nil?
      self.errors.add(:ip_address, :invalid)
      return
    end

    if val.is_a?(IPAddr)
      write_attribute(:ip_address, val)
      return
    end

    v = IPAddr.handle_wildcards(val)

    if v.nil?
      self.errors.add(:ip_address, :invalid)
      return
    end

    write_attribute(:ip_address, v)

  rescue ArgumentError, IPAddr::InvalidAddressError
    self.errors.add(:ip_address, :invalid)
  end

  def ip_address_with_mask
    ip_address.try(:to_cidr_s)
  end

  def self.match_for_ip_address(ip_address)
    find_by("'#{ip_address.to_s}' <<= ip_address")
  end

  def self.should_block?(ip_address)
    exists_for_ip_address_and_action?(ip_address, actions[:block])
  end

  def self.is_whitelisted?(ip_address)
    exists_for_ip_address_and_action?(ip_address, actions[:do_nothing])
  end

  def self.exists_for_ip_address_and_action?(ip_address, action_type, opts={})
    b = match_for_ip_address(ip_address)
    found = (!!b and b.action_type == action_type)
    b.record_match! if found and opts[:record_match] != false
    found
  end

  def self.block_admin_login?(user, ip_address)
    return false if user.nil?
    return false if !user.admin?
    return false if ScreenedIpAddress.where(action_type: actions[:allow_admin]).count == 0
    return true if ip_address.nil?
    !exists_for_ip_address_and_action?(ip_address, actions[:allow_admin], record_match: false)
  end

  def self.star_subnets_query
    @star_subnets_query ||= <<-SQL
      SELECT network(inet(host(ip_address) || '/24')) AS ip_range
        FROM screened_ip_addresses
       WHERE action_type = #{ScreenedIpAddress.actions[:block]}
         AND family(ip_address) = 4
         AND masklen(ip_address) = 32
    GROUP BY ip_range
      HAVING COUNT(*) >= :min_count
    SQL
  end

  def self.star_star_subnets_query
    @star_star_subnets_query ||= <<-SQL
      WITH weighted_subnets AS (
        SELECT network(inet(host(ip_address) || '/16')) AS ip_range,
               CASE masklen(ip_address)
                 WHEN 32 THEN 1
                 WHEN 24 THEN :roll_up_weight
                 ELSE 0
               END AS weight
          FROM screened_ip_addresses
         WHERE action_type = #{ScreenedIpAddress.actions[:block]}
           AND family(ip_address) = 4
      )
      SELECT ip_range
        FROM weighted_subnets
    GROUP BY ip_range
      HAVING SUM(weight) >= :min_count
    SQL
  end

  def self.star_subnets
    min_count = SiteSetting.min_ban_entries_for_roll_up
    ScreenedIpAddress.exec_sql(star_subnets_query, min_count: min_count).values.flatten
  end

  def self.star_star_subnets
    weight = SiteSetting.min_ban_entries_for_roll_up
    ScreenedIpAddress.exec_sql(star_star_subnets_query, min_count: 10, roll_up_weight: weight).values.flatten
  end

  def self.roll_up(current_user=Discourse.system_user)
    subnets = [star_subnets, star_star_subnets].flatten

    StaffActionLogger.new(current_user).log_roll_up(subnets) unless subnets.blank?

    subnets.each do |subnet|
      ScreenedIpAddress.new(ip_address: subnet).save unless ScreenedIpAddress.where(ip_address: subnet).exists?

      sql = <<-SQL
        UPDATE screened_ip_addresses
           SET match_count   = sum_match_count,
               created_at    = min_created_at,
               last_match_at = max_last_match_at
          FROM (
            SELECT SUM(match_count)   AS sum_match_count,
                   MIN(created_at)    AS min_created_at,
                   MAX(last_match_at) AS max_last_match_at
              FROM screened_ip_addresses
             WHERE action_type = #{ScreenedIpAddress.actions[:block]}
               AND family(ip_address) = 4
               AND ip_address << :ip_address
          ) s
         WHERE ip_address = :ip_address
      SQL

      ScreenedIpAddress.exec_sql(sql, ip_address: subnet)

      ScreenedIpAddress.where(action_type: ScreenedIpAddress.actions[:block])
                       .where("family(ip_address) = 4")
                       .where("ip_address << ?", subnet)
                       .delete_all
    end

    subnets
  end

end

