require_dependency 'discourse'
require 'ipaddr'
require 'url_helper'

class TopicLinkClick < ActiveRecord::Base
  belongs_to :topic_link, counter_cache: :clicks
  belongs_to :user

  validates_presence_of :topic_link_id
  validates_presence_of :ip_address

  WHITELISTED_REDIRECT_HOSTNAMES = Set.new(%W{www.youtube.com youtu.be})

  def self.create_from(args={})
    url = args[:url]
    return nil if url.blank?

    uri = URI.parse(url) rescue nil

    urls = Set.new
    urls << url
    if url =~ /^http/
      urls << url.sub(/^https/, 'http')
      urls << url.sub(/^http:/, 'https:')
      urls << UrlHelper.schemaless(url)
    end
    urls << UrlHelper.absolute_without_cdn(url)
    urls << uri.path if uri.try(:host) == Discourse.current_hostname
    urls << url.sub(/\?.*$/, '') if url.include?('?')

    if uri && Discourse.asset_host.present?
      cdn_uri = URI.parse(Discourse.asset_host) rescue nil
      if cdn_uri && cdn_uri.hostname == uri.hostname && uri.path.starts_with?(cdn_uri.path)
        is_cdn_link = true
        urls << uri.path[(cdn_uri.path.length)..-1]
      end
    end

    link = TopicLink.select([:id, :user_id])

    link = link.where(Array.new(urls.count, "url = ?").join(" OR "), *urls)

    link = link.where(post_id: args[:post_id]) if args[:post_id].present?

    link = link.where(topic_id: args[:topic_id]) if args[:topic_id].present?
    link = link.first

    unless link.present?
      return url if url =~ /^\// || uri.try(:host) == Discourse.current_hostname

      link = TopicLink.find_by(url: url)
      return link.url if link.present?

      return nil unless uri

      return url if WHITELISTED_REDIRECT_HOSTNAMES.include?(uri.hostname) || is_cdn_link

      return nil
    end

    return url if args[:user_id] && link.user_id == args[:user_id]

    rate_key = "link-clicks:#{link.id}:#{args[:user_id] || args[:ip]}"
    if $redis.setnx(rate_key, "1")
      $redis.expire(rate_key, 1.day.to_i)
      create!(topic_link_id: link.id, user_id: args[:user_id], ip_address: args[:ip])
    end

    url
  end

end

