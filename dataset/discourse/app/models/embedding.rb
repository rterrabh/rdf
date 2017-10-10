require 'has_errors'

class Embedding < OpenStruct
  include HasErrors

  def self.settings
    %i(embed_by_username
       embed_post_limit
       embed_truncate
       embed_whitelist_selector
       embed_blacklist_selector
       feed_polling_enabled
       feed_polling_url
       embed_username_key_from_feed)
  end

  def base_url
    Discourse.base_url
  end

  def save
    Embedding.settings.each do |s|
      #nodyna <send-370> <SD MODERATE (array)>
      #nodyna <send-371> <SD MODERATE (array)>
      SiteSetting.send("#{s}=", send(s))
    end
    true
  rescue Discourse::InvalidParameters => p
    errors.add :base, p.to_s
    false
  end

  def embeddable_hosts
    EmbeddableHost.all.order(:host)
  end

  def self.find
    embedding_args = { id: 'default' }

    #nodyna <send-372> <SD MODERATE (array)>
    Embedding.settings.each {|s| embedding_args[s] = SiteSetting.send(s) }
    Embedding.new(embedding_args)
  end
end
