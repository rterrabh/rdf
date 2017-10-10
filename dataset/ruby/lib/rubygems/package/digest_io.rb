
class Gem::Package::DigestIO


  attr_reader :digests


  def self.wrap io, digests
    digest_io = new io, digests

    yield digest_io

    return digests
  end


  def initialize io, digests
    @io = io
    @digests = digests
  end


  def write data
    result = @io.write data

    @digests.each do |_, digest|
      digest << data
    end

    result
  end

end

