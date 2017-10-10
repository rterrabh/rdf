module API
  class Labels < Grape::API
    before { authenticate! }

    resource :projects do
      get ':id/labels' do
        present user_project.labels, with: Entities::Label
      end

      post ':id/labels' do
        authorize! :admin_label, user_project
        required_attributes! [:name, :color]

        attrs = attributes_for_keys [:name, :color]
        label = user_project.find_label(attrs[:name])

        conflict!('Label already exists') if label

        label = user_project.labels.create(attrs)

        if label.valid?
          present label, with: Entities::Label
        else
          render_validation_error!(label)
        end
      end

      delete ':id/labels' do
        authorize! :admin_label, user_project
        required_attributes! [:name]

        label = user_project.find_label(params[:name])
        not_found!('Label') unless label

        label.destroy
      end

      put ':id/labels' do
        authorize! :admin_label, user_project
        required_attributes! [:name]

        label = user_project.find_label(params[:name])
        not_found!('Label not found') unless label

        attrs = attributes_for_keys [:new_name, :color]

        if attrs.empty?
          render_api_error!('Required parameters "new_name" or "color" ' \
                            'missing',
                            400)
        end

        attrs[:name] = attrs.delete(:new_name) if attrs.key?(:new_name)

        if label.update(attrs)
          present label, with: Entities::Label
        else
          render_validation_error!(label)
        end
      end
    end
  end
end
