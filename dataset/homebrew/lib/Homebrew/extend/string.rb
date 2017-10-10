class String
  def undent
    gsub(/^[ \t]{#{(slice(/^[ \t]+/) || '').length}}/, "")
  end

  alias_method :undent_________________________________________________________72, :undent

  def chuzzle
    s = chomp
    s unless s.empty?
  end
end

class NilClass
  def chuzzle; end
end

module StringInreplaceExtension
  attr_accessor :errors

  def self.extended(str)
    str.errors = []
  end

  def sub!(before, after)
    result = super
    unless result
      errors << "expected replacement of #{before.inspect} with #{after.inspect}"
    end
    result
  end

  def gsub!(before, after, audit_result = true)
    result = super(before, after)
    if audit_result && result.nil?
      errors << "expected replacement of #{before.inspect} with #{after.inspect}"
    end
    result
  end

  def change_make_var!(flag, new_value)
    unless gsub!(/^#{Regexp.escape(flag)}[ \t]*=[ \t]*(.*)$/, "#{flag}=#{new_value}", false)
      errors << "expected to change #{flag.inspect} to #{new_value.inspect}"
    end
  end

  def remove_make_var!(flags)
    Array(flags).each do |flag|
      unless gsub!(/^#{Regexp.escape(flag)}[ \t]*=.*$\n?/, "", false)
        errors << "expected to remove #{flag.inspect}"
      end
    end
  end

  def get_make_var(flag)
    self[/^#{Regexp.escape(flag)}[ \t]*=[ \t]*(.*)$/, 1]
  end
end
