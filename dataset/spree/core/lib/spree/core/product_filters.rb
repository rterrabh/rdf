module Spree
  module Core



    module ProductFilters
      Spree::Product.add_search_scope :price_range_any do |*opts|
        conds = opts.map {|o| Spree::Core::ProductFilters.price_filter[:conds][o]}.reject { |c| c.nil? }
        scope = conds.shift
        conds.each do |new_scope|
          scope = scope.or(new_scope)
        end
        Spree::Product.joins(master: :default_price).where(scope)
      end

      def ProductFilters.format_price(amount)
        Spree::Money.new(amount)
      end

      def ProductFilters.price_filter
        v = Spree::Price.arel_table
        conds = [ [ Spree.t(:under_price, price: format_price(10))     , v[:amount].lteq(10)],
                  [ "#{format_price(10)} - #{format_price(15)}"        , v[:amount].in(10..15)],
                  [ "#{format_price(15)} - #{format_price(18)}"        , v[:amount].in(15..18)],
                  [ "#{format_price(18)} - #{format_price(20)}"        , v[:amount].in(18..20)],
                  [ Spree.t(:or_over_price, price: format_price(20)) , v[:amount].gteq(20)]]
        {
          name:   Spree.t(:price_range),
          scope:  :price_range_any,
          conds:  Hash[*conds.flatten],
          labels: conds.map { |k,v| [k, k] }
        }
      end


      Spree::Product.add_search_scope :brand_any do |*opts|
        conds = opts.map {|o| ProductFilters.brand_filter[:conds][o]}.reject { |c| c.nil? }
        scope = conds.shift
        conds.each do |new_scope|
          scope = scope.or(new_scope)
        end
        Spree::Product.with_property('brand').where(scope)
      end

      def ProductFilters.brand_filter
        brand_property = Spree::Property.find_by(name: 'brand')
        brands = brand_property ? Spree::ProductProperty.where(property_id: brand_property.id).pluck(:value).uniq.map(&:to_s) : []
        pp = Spree::ProductProperty.arel_table
        conds = Hash[*brands.map { |b| [b, pp[:value].eq(b)] }.flatten]
        {
          name:   'Brands',
          scope:  :brand_any,
          conds:  conds,
          labels: (brands.sort).map { |k| [k, k] }
        }
      end

      Spree::Product.add_search_scope :selective_brand_any do |*opts|
        Spree::Product.brand_any(*opts)
      end

      def ProductFilters.selective_brand_filter(taxon = nil)
        taxon ||= Spree::Taxonomy.first.root
        brand_property = Spree::Property.find_by(name: 'brand')
        scope = Spree::ProductProperty.where(property: brand_property).
          joins(product: :taxons).
          where("#{Spree::Taxon.table_name}.id" => [taxon] + taxon.descendants)
        brands = scope.pluck(:value).uniq
        {
          name:   'Applicable Brands',
          scope:  :selective_brand_any,
          labels: brands.sort.map { |k| [k, k] }
        }
      end

      def ProductFilters.taxons_below(taxon)
        return Spree::Core::ProductFilters.all_taxons if taxon.nil?
        {
          name:   'Taxons under ' + taxon.name,
          scope:  :taxons_id_in_tree_any,
          labels: taxon.children.sort_by(&:position).map { |t| [t.name, t.id] },
          conds:  nil
        }
      end

      def ProductFilters.all_taxons
        taxons = Spree::Taxonomy.all.map { |t| [t.root] + t.root.descendants }.flatten
        {
          name:   'All taxons',
          scope:  :taxons_id_equals_any,
          labels: taxons.sort_by(&:name).map { |t| [t.name, t.id] },
          conds:  nil # not needed
        }
      end
    end
  end
end
