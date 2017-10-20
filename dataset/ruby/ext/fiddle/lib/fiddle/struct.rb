require 'fiddle'
require 'fiddle/value'
require 'fiddle/pack'

module Fiddle
  class CStruct
    def CStruct.entity_class
      CStructEntity
    end
  end

  class CUnion
    def CUnion.entity_class
      CUnionEntity
    end
  end

  module CStructBuilder
    def create(klass, types, members)
      new_class = Class.new(klass){
        #nodyna <define_method-1489> <DM COMPLEX (events)>
        define_method(:initialize){|addr|
          @entity = klass.entity_class.new(addr, types)
          @entity.assign_names(members)
        }
        #nodyna <define_method-1490> <DM MODERATE (events)>
        define_method(:to_ptr){ @entity }
        #nodyna <define_method-1491> <DM MODERATE (events)>
        define_method(:to_i){ @entity.to_i }
        members.each{|name|
          #nodyna <define_method-1492> <DM COMPLEX (events)>
          define_method(name){ @entity[name] }
          #nodyna <define_method-1493> <DM COMPLEX (events)>
          define_method(name + "="){|val| @entity[name] = val }
        }
      }
      size = klass.entity_class.size(types)
      #nodyna <module_eval-1494> <ME COMPLEX (define methods)>
      new_class.module_eval(<<-EOS, __FILE__, __LINE__+1)
        def new_class.size()
        end
        def new_class.malloc()
          addr = Fiddle.malloc(#{size})
          new(addr)
        end
      EOS
      return new_class
    end
    module_function :create
  end

  class CStructEntity < Fiddle::Pointer
    include PackInfo
    include ValueUtil

    def CStructEntity.malloc(types, func = nil)
      addr = Fiddle.malloc(CStructEntity.size(types))
      CStructEntity.new(addr, types, func)
    end

    def CStructEntity.size(types)
      offset = 0

      max_align = types.map { |type, count = 1|
        last_offset = offset

        align = PackInfo::ALIGN_MAP[type]
        offset = PackInfo.align(last_offset, align) +
                 (PackInfo::SIZE_MAP[type] * count)

        align
      }.max

      PackInfo.align(offset, max_align)
    end

    def initialize(addr, types, func = nil)
      set_ctypes(types)
      super(addr, @size, func)
    end

    def assign_names(members)
      @members = members
    end

    def set_ctypes(types)
      @ctypes = types
      @offset = []
      offset = 0

      max_align = types.map { |type, count = 1|
        orig_offset = offset
        align = ALIGN_MAP[type]
        offset = PackInfo.align(orig_offset, align)

        @offset << offset

        offset += (SIZE_MAP[type] * count)

        align
      }.max

      @size = PackInfo.align(offset, max_align)
    end

    def [](name)
      idx = @members.index(name)
      if( idx.nil? )
        raise(ArgumentError, "no such member: #{name}")
      end
      ty = @ctypes[idx]
      if( ty.is_a?(Array) )
        r = super(@offset[idx], SIZE_MAP[ty[0]] * ty[1])
      else
        r = super(@offset[idx], SIZE_MAP[ty.abs])
      end
      packer = Packer.new([ty])
      val = packer.unpack([r])
      case ty
      when Array
        case ty[0]
        when TYPE_VOIDP
          val = val.collect{|v| Pointer.new(v)}
        end
      when TYPE_VOIDP
        val = Pointer.new(val[0])
      else
        val = val[0]
      end
      if( ty.is_a?(Integer) && (ty < 0) )
        return unsigned_value(val, ty)
      elsif( ty.is_a?(Array) && (ty[0] < 0) )
        return val.collect{|v| unsigned_value(v,ty[0])}
      else
        return val
      end
    end

    def []=(name, val)
      idx = @members.index(name)
      if( idx.nil? )
        raise(ArgumentError, "no such member: #{name}")
      end
      ty  = @ctypes[idx]
      packer = Packer.new([ty])
      val = wrap_arg(val, ty, [])
      buff = packer.pack([val].flatten())
      super(@offset[idx], buff.size, buff)
      if( ty.is_a?(Integer) && (ty < 0) )
        return unsigned_value(val, ty)
      elsif( ty.is_a?(Array) && (ty[0] < 0) )
        return val.collect{|v| unsigned_value(v,ty[0])}
      else
        return val
      end
    end

    def to_s() # :nodoc:
      super(@size)
    end
  end

  class CUnionEntity < CStructEntity
    include PackInfo

    def CUnionEntity.malloc(types, func=nil)
      addr = Fiddle.malloc(CUnionEntity.size(types))
      CUnionEntity.new(addr, types, func)
    end

    def CUnionEntity.size(types)
      types.map { |type, count = 1|
        PackInfo::SIZE_MAP[type] * count
      }.max
    end

    def set_ctypes(types)
      @ctypes = types
      @offset = Array.new(types.length, 0)
      @size   = self.class.size types
    end
  end
end

