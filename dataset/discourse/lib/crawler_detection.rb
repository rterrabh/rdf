module CrawlerDetection

  def self.crawler?(user_agent)
    !/Googlebot|Mediapartners|AdsBot|curl|Twitterbot|facebookexternalhit|bingbot|Baiduspider|ia_archiver|Wayback Save Page|360Spider|Swiftbot/.match(user_agent).nil?
  end
end
