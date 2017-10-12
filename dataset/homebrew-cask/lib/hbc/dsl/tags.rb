class Hbc::DSL::Tags

  VALID_TAGS = Set.new [
                        :vendor
                       ]

  attr_accessor *VALID_TAGS
  attr_accessor :pairs

  def initialize(pairs={})
    @pairs = pairs
    @pairs.each do |key, value|
      raise "invalid tags key: '#{key.inspect}'" unless VALID_TAGS.include?(key)
      writer_method = "#{key}=".to_sym
      #nodyna <send-2855> <SD COMPLEX (array)>
      send(writer_method, value)
    end
  end

  def to_yaml
    @pairs.to_yaml
  end

  def to_s
    @pairs.inspect
  end
end
