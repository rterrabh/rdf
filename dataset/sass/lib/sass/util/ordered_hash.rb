
class OrderedHash < ::Hash

  def initialize(*args)
    super
    @keys = []
  end

  def self.[](*args)
    ordered_hash = new

    if args.length == 1 && args.first.is_a?(Array)
      args.first.each do |key_value_pair|
        next unless key_value_pair.is_a?(Array)
        ordered_hash[key_value_pair[0]] = key_value_pair[1]
      end

      return ordered_hash
    end

    unless args.size.even?
      raise ArgumentError.new("odd number of arguments for Hash")
    end

    args.each_with_index do |val, ind|
      next if ind.odd?
      ordered_hash[val] = args[ind + 1]
    end

    ordered_hash
  end

  def initialize_copy(other)
    super
    @keys = other.keys
  end

  def []=(key, value)
    @keys << key unless has_key?(key)
    super
  end

  def delete(key)
    if has_key? key
      index = @keys.index(key)
      @keys.delete_at index
    end
    super
  end

  def delete_if
    super
    sync_keys!
    self
  end

  def reject!
    super
    sync_keys!
    self
  end

  def reject
    dup.reject! {|h, k| yield h, k}
  end

  def keys
    @keys.dup
  end

  def values
    @keys.map {|key| self[key]}
  end

  def to_hash
    self
  end

  def to_a
    @keys.map {|key| [key, self[key]]}
  end

  def each_key
    return to_enum(:each_key) unless block_given?
    @keys.each {|key| yield key}
    self
  end

  def each_value
    return to_enum(:each_value) unless block_given?
    @keys.each {|key| yield self[key]}
    self
  end

  def each
    return to_enum(:each) unless block_given?
    @keys.each {|key| yield [key, self[key]]}
    self
  end

  def each_pair
    return to_enum(:each_pair) unless block_given?
    @keys.each {|key| yield key, self[key]}
    self
  end

  alias_method :select, :find_all

  def clear
    super
    @keys.clear
    self
  end

  def shift
    k = @keys.first
    v = delete(k)
    [k, v]
  end

  def merge!(other_hash)
    if block_given?
      other_hash.each {|k, v| self[k] = key?(k) ? yield(k, self[k], v) : v}
    else
      other_hash.each {|k, v| self[k] = v}
    end
    self
  end

  alias_method :update, :merge!

  def merge(other_hash)
    if block_given?
      dup.merge!(other_hash) {|k, v1, v2| yield k, v1, v2}
    else
      dup.merge!(other_hash)
    end
  end

  def replace(other)
    super
    @keys = other.keys
    self
  end

  def invert
    OrderedHash[to_a.map! {|key_value_pair| key_value_pair.reverse}]
  end

  def inspect
    "#<OrderedHash #{super}>"
  end

  private

  def sync_keys!
    @keys.delete_if {|k| !has_key?(k)}
  end
end
