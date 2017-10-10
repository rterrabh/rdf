module ExtractsPath
  class InvalidPathError < StandardError; end

  def extract_ref(id)
    pair = ['', '']

    return pair unless @project

    if id.match(/^([[:alnum:]]{40})(.+)/)
      pair = $~.captures
    else

      id += '/' unless id.ends_with?('/')

      valid_refs = @project.repository.ref_names
      valid_refs.select! { |v| id.start_with?("#{v}/") }

      if valid_refs.length == 0
        pair = id.match(/([^\/]+)(.*)/).captures
      else
        best_match = valid_refs.max_by(&:length)
        pair = id.partition(best_match)[1..-1]
      end
    end

    pair[1].gsub!(/^\/|\/$/, '')

    pair
  end

  def assign_ref_vars
    allowed_options = ["filter_ref", "extended_sha1"]
    @options = params.select {|key, value| allowed_options.include?(key) && !value.blank? }
    @options = HashWithIndifferentAccess.new(@options)

    @id = Addressable::URI.unescape(get_id)
    @ref, @path = extract_ref(@id)
    @repo = @project.repository
    if @options[:extended_sha1].blank?
      @commit = @repo.commit(@ref)
    else
      @commit = @repo.commit(@options[:extended_sha1])
    end

    raise InvalidPathError unless @commit

    @hex_path = Digest::SHA1.hexdigest(@path)
    @logs_path = logs_file_namespace_project_ref_path(@project.namespace,
                                                      @project, @ref, @path)

  rescue RuntimeError, NoMethodError, InvalidPathError
    not_found!
  end

  def tree
    @tree ||= @repo.tree(@commit.id, @path)
  end

  private

  def get_id
    id = params[:id] || params[:ref]
    id += "/" + params[:path] unless params[:path].blank?
    id
  end
end
