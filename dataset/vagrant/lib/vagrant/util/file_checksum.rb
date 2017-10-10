class DigestClass
  def update(string); end
  def hexdigest; end
end

class FileChecksum
  BUFFER_SIZE = 1024 * 8

  def initialize(path, digest_klass)
    @digest_klass = digest_klass
    @path         = path
  end

  def checksum
    digest = @digest_klass.new
    buf = ''

    File.open(@path, "rb") do |f|
      while !f.eof
        begin
          f.readpartial(BUFFER_SIZE, buf)
          digest.update(buf)
        rescue EOFError
          break
        end
      end
    end

    return digest.hexdigest
  end
end
