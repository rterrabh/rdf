class String
  def titlecase
    small_words = %w(a an and as at but by en for if in of on or the to v v. via vs vs.)

    x = split(" ").map do |word|
      small_words.include?(word.gsub(/\W/, "").downcase) ? word.downcase! : word.smart_capitalize!
      word
    end
    x.first.to_s.smart_capitalize!
    x.last.to_s.smart_capitalize!
    x.join(" ").gsub(/(:|\.|!|\?)\s?(\W*#{small_words.join("|")}\W*)\s/) { "#{$1} #{$2.smart_capitalize} " }
  end

  def titlecase!
    replace(titlecase)
  end

  def smart_capitalize
    if self =~ /^['"\(\[']*([a-z])/
      i = index($1)
      x = self[i,self.length]
      self[i,1] = self[i,1].upcase unless x =~ /[A-Z]/ or x =~ /\.\w+/
    end
    self
  end

  def smart_capitalize!
    replace(smart_capitalize)
  end
end
