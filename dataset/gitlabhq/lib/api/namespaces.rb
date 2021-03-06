module API
  class Namespaces < Grape::API
    before { authenticate! }

    resource :namespaces do
      get do
        @namespaces = if current_user.admin
                        Namespace.all
                      else
                        current_user.namespaces
                      end
        @namespaces = @namespaces.search(params[:search]) if params[:search].present?
        @namespaces = paginate @namespaces

        present @namespaces, with: Entities::Namespace
      end
    end
  end
end
