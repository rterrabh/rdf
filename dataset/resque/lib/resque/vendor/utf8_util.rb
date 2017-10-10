module UTF8Util
  REPLACEMENT_CHAR = "?"

  def self.clean!(str)
    raise NotImplementedError
  end

  def self.clean(str)
    clean!(str.dup)
  end

end

if RUBY_VERSION <= '1.9'
  require 'resque/vendor/utf8_util/utf8_util_18'
else
  require 'resque/vendor/utf8_util/utf8_util_19'
end
