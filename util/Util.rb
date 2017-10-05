class Util

  def self.extractFiles(pathes)
    files = []
    pathes.each do |path|
      files += Dir.glob(path)
    end
    files.flatten!
    files
  end

end
