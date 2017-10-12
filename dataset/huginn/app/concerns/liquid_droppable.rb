module LiquidDroppable
  extend ActiveSupport::Concern

  class Drop < Liquid::Drop
    def initialize(object)
      @object = object
    end

    def to_s
      @object.to_s
    end

    def each
      (public_instance_methods - Drop.public_instance_methods).each { |name|
        yield [name, __send__(name)]
      }
    end
  end

  included do
    #nodyna <const_set-2939> <CS TRIVIAL (public constant)>
    const_set :Drop,
              if Kernel.const_defined?(drop_name = "#{name}Drop")
                #nodyna <const_get-2940> <CG COMPLEX (change-prone variables)>
                Kernel.const_get(drop_name)
              else
                #nodyna <const_set-2941> <CG COMPLEX (change-prone variables)>
                Kernel.const_set(drop_name, Class.new(Drop))
              end
  end

  def to_liquid
    self.class::Drop.new(self)
  end

  require 'uri'

  class URIDrop < Drop
    URI::Generic::COMPONENT.each { |attr|
      #nodyna <define_method-2942> <DM MODERATE (array)>
      define_method(attr) {
        @object.__send__(attr)
      }
    }
  end

  class ::URI::Generic
    def to_liquid
      URIDrop.new(self)
    end
  end
end
