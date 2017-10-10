class HelpController < ApplicationController
  layout 'help'

  def index
  end

  def show
    @category = clean_path_info(path_params[:category])
    @file = path_params[:file]

    respond_to do |format|
      format.any(:markdown, :md, :html) do
        path = File.join(Rails.root, 'doc', @category, "#{@file}.md")

        if File.exist?(path)
          @markdown = File.read(path)

          render 'show.html.haml'
        else
          render 'errors/not_found.html.haml', layout: 'errors', status: 404
        end
      end

      format.any(:png, :gif, :jpeg) do
        path = File.join(Rails.root, 'doc', @category, "#{@file}.#{params[:format]}")

        if File.exist?(path)
          send_file(path, disposition: 'inline')
        else
          head :not_found
        end
      end

      format.any { head :not_found }
    end
  end

  def shortcuts
  end

  def ui
  end

  private

  def path_params
    params.require(:category)
    params.require(:file)

    params
  end

  PATH_SEPS = Regexp.union(*[::File::SEPARATOR, ::File::ALT_SEPARATOR].compact)

  def clean_path_info(path_info)
    parts = path_info.split(PATH_SEPS)

    clean = []

    parts.each do |part|
      next if part.empty? || part == '.'

      if part == '..'
        clean.pop
      else
        clean << part
      end
    end

    clean.unshift '/' if parts.empty? || parts.first.empty?

    ::File.join(*clean)
  end
end
