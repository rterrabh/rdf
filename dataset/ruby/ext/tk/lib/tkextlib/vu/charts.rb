require 'tk'
require 'tk/canvas'

require 'tkextlib/vu.rb'

module Tk
  module Vu
    module ChartsConfig
      include TkItemConfigOptkeys
      def __item_boolval_optkeys(id)
        super(id) << 'lefttrunc' << 'autocolor'
      end
      private :__item_boolval_optkeys

      def __item_strval_optkeys(id)
        super(id) << 'bar' << 'color' << 'outline' <<
          'fill' << 'scaleline' << 'stripline'
      end
      private :__item_strval_optkeys

      def __item_listval_optkeys(id)
        super(id) << 'values' << 'tags'
      end
      private :__item_listval_optkeys
    end

    class TkcSticker < TkcItem
      include ChartsConfig

      CItemTypeName = 'sticker'.freeze
      CItemTypeToClass[CItemTypeName] = self
    end

    class TkcStripchart < TkcItem
      include ChartsConfig

      CItemTypeName = 'stripchart'.freeze
      CItemTypeToClass[CItemTypeName] = self
    end

    class TkcBarchart < TkcItem
      include ChartsConfig

      CItemTypeName = 'barchart'.freeze
      CItemTypeToClass[CItemTypeName] = self
    end
  end
end
