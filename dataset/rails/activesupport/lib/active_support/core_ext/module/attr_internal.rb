class Module
  def attr_internal_reader(*attrs)
    attrs.each {|attr_name| attr_internal_define(attr_name, :reader)}
  end

  def attr_internal_writer(*attrs)
    attrs.each {|attr_name| attr_internal_define(attr_name, :writer)}
  end

  def attr_internal_accessor(*attrs)
    attr_internal_reader(*attrs)
    attr_internal_writer(*attrs)
  end
  alias_method :attr_internal, :attr_internal_accessor

  class << self; attr_accessor :attr_internal_naming_format end
  self.attr_internal_naming_format = '@_%s'

  private
    def attr_internal_ivar_name(attr)
      Module.attr_internal_naming_format % attr
    end

    def attr_internal_define(attr_name, type)
      internal_name = attr_internal_ivar_name(attr_name).sub(/\A@/, '')
      #nodyna <class_eval-1049> <CE MODERATE (block execution)>
      class_eval do
        #nodyna <send-1050> <SD MODERATE (change-prone variables)>
        send("attr_#{type}", internal_name)
      end
      attr_name, internal_name = "#{attr_name}=", "#{internal_name}=" if type == :writer
      alias_method attr_name, internal_name
      remove_method internal_name
    end
end
