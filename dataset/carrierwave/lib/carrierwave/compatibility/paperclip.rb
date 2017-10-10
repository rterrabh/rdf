
module CarrierWave
  module Compatibility

    module Paperclip
      extend ActiveSupport::Concern

      DEFAULT_MAPPINGS = {
        :rails_root   => lambda{|u, f| Rails.root.to_s },
        :rails_env    => lambda{|u, f| Rails.env },
        :id_partition => lambda{|u, f| ("%09d" % u.model.id).scan(/\d{3}/).join("/")},
        :id           => lambda{|u, f| u.model.id },
        :attachment   => lambda{|u, f| u.mounted_as.to_s.downcase.pluralize },
        :style        => lambda{|u, f| u.paperclip_style },
        :basename     => lambda{|u, f| u.filename.gsub(/#{File.extname(u.filename)}$/, "") },
        :extension    => lambda{|u, d| File.extname(u.filename).gsub(/^\.+/, "")},
        :class        => lambda{|u, f| u.model.class.name.underscore.pluralize}
      }

      included do
        attr_accessor :filename
        class_attribute :mappings
        self.mappings ||= DEFAULT_MAPPINGS.dup
      end

      def store_path(for_file=filename)
        path = paperclip_path
        self.filename = for_file
        path ||= File.join(*[store_dir, paperclip_style.to_s, for_file].compact)
        interpolate_paperclip_path(path)
      end

      def store_dir
        ":rails_root/public/system/:attachment/:id"
      end

      def paperclip_default_style
        :original
      end

      def paperclip_path
      end

      def paperclip_style
        version_name || paperclip_default_style
      end

      module ClassMethods
        def interpolate(sym, &block)
          mappings[sym] = block
        end
      end

      private
      def interpolate_paperclip_path(path)
        mappings.each_pair.inject(path) do |agg, pair|
          agg.gsub(":#{pair[0]}") { pair[1].call(self, self.paperclip_style).to_s }
        end
      end
    end # Paperclip
  end # Compatibility
end # CarrierWave
