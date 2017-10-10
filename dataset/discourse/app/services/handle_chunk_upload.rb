class HandleChunkUpload

  def initialize(chunk, params={})
    @chunk = chunk
    @params = params
  end

  def self.check_chunk(chunk, params)
    HandleChunkUpload.new(chunk, params).check_chunk
  end

  def self.upload_chunk(chunk, params)
    HandleChunkUpload.new(chunk, params).upload_chunk
  end

  def self.merge_chunks(chunk, params)
    HandleChunkUpload.new(chunk, params).merge_chunks
  end

  def check_chunk
    has_chunk_been_uploaded = File.exists?(@chunk) && File.size(@chunk) == @params[:current_chunk_size]
    status = has_chunk_been_uploaded ? 200 : 404
  end

  def upload_chunk
    dir = File.dirname(@chunk)
    FileUtils.mkdir_p(dir) unless Dir.exists?(dir)
    File.open(@chunk, "wb") { |f| f.write(@params[:file].tempfile.read) }
  end

  def merge_chunks
    upload_path     = @params[:upload_path]
    tmp_upload_path = @params[:tmp_upload_path]
    model           = @params[:model]
    identifier      = @params[:identifier]
    filename        = @params[:filename]
    tmp_directory   = @params[:tmp_directory]

    File.delete(upload_path) rescue nil
    File.delete(tmp_upload_path) rescue nil

    File.open(tmp_upload_path, "a") do |file|
      (1..@chunk).each do |chunk_number|
        chunk_path = model.chunk_path(identifier, filename, chunk_number)
        file << File.open(chunk_path).read
      end
    end

    FileUtils.mv(tmp_upload_path, upload_path, force: true)

    FileUtils.rm_rf(tmp_directory) rescue nil
  end

end
