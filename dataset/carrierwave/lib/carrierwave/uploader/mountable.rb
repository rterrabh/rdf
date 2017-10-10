
module CarrierWave
  module Uploader
    module Mountable

      attr_reader :model, :mounted_as

      def initialize(model=nil, mounted_as=nil)
        @model = model
        @mounted_as = mounted_as
      end

    end # Mountable
  end # Uploader
end # CarrierWave
