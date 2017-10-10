require_dependency 'embedding'

class Admin::EmbeddingController < Admin::AdminController

  before_filter :ensure_logged_in, :ensure_staff, :fetch_embedding

  def show
    render_serialized(@embedding, EmbeddingSerializer, root: 'embedding', rest_serializer: true)
  end

  def update
    Embedding.settings.each do |s|
      #nodyna <send-446> <SD MODERATE (array)>
      @embedding.send("#{s}=", params[:embedding][s])
    end

    if @embedding.save
      fetch_embedding
      render_serialized(@embedding, EmbeddingSerializer, root: 'embedding', rest_serializer: true)
    else
      render_json_error(@embedding)
    end
  end

  protected

    def fetch_embedding
      @embedding = Embedding.find
    end
end
