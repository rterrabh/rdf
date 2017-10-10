module ActiveModel

  module Model
    extend ActiveSupport::Concern
    include ActiveModel::Validations
    include ActiveModel::Conversion

    included do
      extend ActiveModel::Naming
      extend ActiveModel::Translation
    end

    def initialize(params={})
      params.each do |attr, value|
        #nodyna <send-974> <SD COMPLEX (array)>
        self.public_send("#{attr}=", value)
      end if params

      super()
    end

    def persisted?
      false
    end
  end
end
