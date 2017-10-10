module EnsureMagic

  def method_missing(method, *args, &block)
    if method.to_s =~ /^ensure_(.*)\!$/
      can_method = :"#{Regexp.last_match[1]}?"

      if respond_to?(can_method)
        #nodyna <send-317> <SD COMPLEX (change-prone variables)>
        raise Discourse::InvalidAccess.new("#{can_method} failed") unless send(can_method, *args, &block)
        return
      end
    end

    super.method_missing(method, *args, &block)
  end

  def ensure_can_see!(obj)
    raise Discourse::InvalidAccess.new("Can't see #{obj}") unless can_see?(obj)
  end

end
