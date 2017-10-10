require 'stringex'

module Spree
  class Taxon < Spree::Base
    extend FriendlyId
    friendly_id :permalink, slug_column: :permalink, use: :slugged
    before_create :set_permalink

    acts_as_nested_set dependent: :destroy

    belongs_to :taxonomy, class_name: 'Spree::Taxonomy', inverse_of: :taxons
    has_many :classifications, -> { order(:position) }, dependent: :delete_all, inverse_of: :taxon
    has_many :products, through: :classifications

    has_and_belongs_to_many :prototypes, join_table: :spree_taxons_prototypes

    validates :name, presence: true
    validates :meta_keywords, length: { maximum: 255 }
    validates :meta_description, length: { maximum: 255 }
    validates :meta_title, length: { maximum: 255 }

    after_save :touch_ancestors_and_taxonomy
    after_touch :touch_ancestors_and_taxonomy

    has_attached_file :icon,
      styles: { mini: '32x32>', normal: '128x128>' },
      default_style: :mini,
      url: '/spree/taxons/:id/:style/:basename.:extension',
      path: ':rails_root/public/spree/taxons/:id/:style/:basename.:extension',
      default_url: '/assets/default_taxon.png'

    validates_attachment :icon,
      content_type: { content_type: ["image/jpg", "image/jpeg", "image/png", "image/gif"] }

    def applicable_filters
      fs = []

      fs << Spree::Core::ProductFilters.price_filter if Spree::Core::ProductFilters.respond_to?(:price_filter)
      fs << Spree::Core::ProductFilters.brand_filter if Spree::Core::ProductFilters.respond_to?(:brand_filter)
      fs
    end

    def seo_title
      unless meta_title.blank?
        meta_title
      else
        root? ? name : "#{root.name} - #{name}"
      end
    end

    def set_permalink
      if parent.present?
        self.permalink = [parent.permalink, (permalink.blank? ? name.to_url : permalink.split('/').last)].join('/')
      else
        self.permalink = name.to_url if permalink.blank?
      end
    end

    def active_products
      products.active
    end

    def pretty_name
      ancestor_chain = self.ancestors.inject("") do |name, ancestor|
        name += "#{ancestor.name} -> "
      end
      ancestor_chain + "#{name}"
    end

    def child_index=(idx)
      move_to_child_with_index(parent, idx.to_i) unless self.new_record?
    end

    private

    def touch_ancestors_and_taxonomy
      self.class.where(id: ancestors.pluck(:id)).update_all(updated_at: Time.now)
      taxonomy.try!(:touch)
    end
  end
end
