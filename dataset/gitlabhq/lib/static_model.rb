module StaticModel
  extend ActiveSupport::Concern

  module ClassMethods
    def primary_key
      'id'
    end

    def base_class
      self
    end
  end

  def [](key)
    #nodyna <send-490> <SD COMPLEX (change-prone variables)>
    send(key) if respond_to?(key)
  end

  def to_param
    id
  end

  def new_record?
    false
  end

  def persisted?
    false
  end

  def destroyed?
    false
  end

  def ==(other)
    if other.is_a? ::StaticModel
      id == other.id
    else
      super
    end
  end
end
