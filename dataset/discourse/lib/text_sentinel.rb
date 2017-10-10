class TextSentinel

  attr_accessor :text

  ENTROPY_SCALE ||= 0.7

  def initialize(text, opts=nil)
    @opts = opts || {}
    @text = text.to_s.encode('UTF-8', invalid: :replace, undef: :replace, replace: '')
  end

  def self.body_sentinel(text, opts={})
    entropy = SiteSetting.body_min_entropy
    if opts[:private_message]
      scale_entropy = SiteSetting.min_private_message_post_length.to_f / SiteSetting.min_post_length.to_f
      entropy = (entropy * scale_entropy).to_i
      entropy = (SiteSetting.min_private_message_post_length.to_f * ENTROPY_SCALE).to_i if entropy > SiteSetting.min_private_message_post_length
    else
      entropy = (SiteSetting.min_post_length.to_f * ENTROPY_SCALE).to_i if entropy > SiteSetting.min_post_length
    end
    TextSentinel.new(text, min_entropy: entropy)
  end

  def self.title_sentinel(text)
    entropy = if SiteSetting.min_topic_title_length > SiteSetting.title_min_entropy
      SiteSetting.title_min_entropy
    else
      (SiteSetting.min_topic_title_length.to_f * ENTROPY_SCALE).to_i
    end
    TextSentinel.new(text, min_entropy: entropy, max_word_length: SiteSetting.title_max_word_length)
  end

  def entropy
    chars = @text.to_s.strip.split('')
    @entropy ||= chars.pack('M*'*chars.size).gsub("\n",'').split('=').uniq.size
  end

  def valid?
    @text.present? &&
    seems_meaningful? &&
    seems_pronounceable? &&
    seems_unpretentious? &&
    seems_quiet?
  end

  private

  def symbols_regex
    /[\ -\/\[-\`\:-\@\{-\~]/m
  end

  def seems_meaningful?
    @opts[:min_entropy].blank? || (entropy >= @opts[:min_entropy])
  end

  def seems_pronounceable?
    @text.gsub(symbols_regex, '').size > 0
  end

  def seems_unpretentious?
    @opts[:max_word_length].blank? || @text.split(/\s|\/|-|\./).map(&:size).max <= @opts[:max_word_length]
  end


  def seems_quiet?
    not((@text =~ /[A-Z]+/) && !(@text =~ /[^[:ascii:]]/) && (@text == @text.upcase))
  end

end
