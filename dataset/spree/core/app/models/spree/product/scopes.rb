module Spree
  class Product < Spree::Base
    cattr_accessor :search_scopes do
      []
    end

    def self.add_search_scope(name, &block)
      #nodyna <send-2524> <SD MODERATE (private methods)>
      #nodyna <define_method-2525> <DM MODERATE (events)>
      self.singleton_class.send(:define_method, name.to_sym, &block)
      search_scopes << name.to_sym
    end

    def self.simple_scopes
      [
        :ascend_by_updated_at,
        :descend_by_updated_at,
        :ascend_by_name,
        :descend_by_name
      ]
    end

    def self.add_simple_scopes(scopes)
      scopes.each do |name|
        next if name.to_s.include?("master_price")
        parts = name.to_s.match(/(.*)_by_(.*)/)
        self.scope(name.to_s, -> { order("#{Product.quoted_table_name}.#{parts[2]} #{parts[1] == 'ascend' ?  "ASC" : "DESC"}") })
      end
    end

    def self.property_conditions(property)
      properties = Property.table_name
      conditions = case property
      when String   then { "#{properties}.name" => property }
      when Property then { "#{properties}.id" => property.id }
      else               { "#{properties}.id" => property.to_i }
      end
    end

    add_simple_scopes simple_scopes

    add_search_scope :ascend_by_master_price do
      joins(:master => :default_price).order("#{price_table_name}.amount ASC")
    end

    add_search_scope :descend_by_master_price do
      joins(:master => :default_price).order("#{price_table_name}.amount DESC")
    end

    add_search_scope :price_between do |low, high|
      joins(:master => :default_price).where(Price.table_name => { :amount => low..high })
    end

    add_search_scope :master_price_lte do |price|
      joins(:master => :default_price).where("#{price_table_name}.amount <= ?", price)
    end

    add_search_scope :master_price_gte do |price|
      joins(:master => :default_price).where("#{price_table_name}.amount >= ?", price)
    end

    add_search_scope :in_taxon do |taxon|
      includes(:classifications).
      where("spree_products_taxons.taxon_id" => taxon.self_and_descendants.pluck(:id)).
      order("spree_products_taxons.position ASC")
    end

    add_search_scope :in_taxons do |*taxons|
      taxons = get_taxons(taxons)
      taxons.first ? prepare_taxon_conditions(taxons) : where(nil)
    end

    add_search_scope :with_property do |property|
      joins(:properties).where(property_conditions(property))
    end

    add_search_scope :with_property_value do |property, value|
      joins(:properties)
        .where("#{ProductProperty.table_name}.value = ?", value)
        .where(property_conditions(property))
    end

    add_search_scope :with_option do |option|
      option_types = OptionType.table_name
      conditions = case option
      when String     then { "#{option_types}.name" => option }
      when OptionType then { "#{option_types}.id" => option.id }
      else                 { "#{option_types}.id" => option.to_i }
      end

      joins(:option_types).where(conditions)
    end

    add_search_scope :with_option_value do |option, value|
      option_values = OptionValue.table_name
      option_type_id = case option
        when String then OptionType.find_by(name: option) || option.to_i
        when OptionType then option.id
        else option.to_i
      end

      conditions = "#{option_values}.name = ? AND #{option_values}.option_type_id = ?", value, option_type_id
      group('spree_products.id').joins(variants_including_master: :option_values).where(conditions)
    end

    add_search_scope :with do |value|
      includes(variants_including_master: :option_values).
      includes(:product_properties).
      where("#{OptionValue.table_name}.name = ? OR #{ProductProperty.table_name}.value = ?", value, value)
    end

    add_search_scope :in_name do |words|
      like_any([:name], prepare_words(words))
    end

    add_search_scope :in_name_or_keywords do |words|
      like_any([:name, :meta_keywords], prepare_words(words))
    end

    add_search_scope :in_name_or_description do |words|
      like_any([:name, :description, :meta_description, :meta_keywords], prepare_words(words))
    end

    add_search_scope :with_ids do |*ids|
      where(id: ids)
    end

    add_search_scope :descend_by_popularity do
      joins(:master).
      order(%Q{
           COALESCE((
             SELECT
               COUNT(#{LineItem.quoted_table_name}.id)
             FROM
             JOIN
             ON
               popular_variants.id = #{LineItem.quoted_table_name}.variant_id
             WHERE
               popular_variants.product_id = #{Product.quoted_table_name}.id
           ), 0) DESC
        })
    end

    add_search_scope :not_deleted do
      where("#{Product.quoted_table_name}.deleted_at IS NULL or #{Product.quoted_table_name}.deleted_at >= ?", Time.zone.now)
    end

    def self.available(available_on = nil, currency = nil)
      joins(:master => :prices).where("#{Product.quoted_table_name}.available_on <= ?", available_on || Time.now)
    end
    search_scopes << :available

    def self.active(currency = nil)
      not_deleted.available(nil, currency)
    end
    search_scopes << :active

    add_search_scope :taxons_name_eq do |name|
      group("spree_products.id").joins(:taxons).where(Taxon.arel_table[:name].eq(name))
    end

    def self.distinct_by_product_ids(sort_order = nil)
      sort_column = sort_order.split(" ").first

      if ActiveRecord::Base.connection.adapter_name == 'PostgreSQL' && !column_names.include?(sort_column)
        all
      else
        distinct
      end
    end

    private

      def self.price_table_name
        Price.quoted_table_name
      end

      def self.prepare_taxon_conditions(taxons)
        ids = taxons.map { |taxon| taxon.self_and_descendants.pluck(:id) }.flatten.uniq
        joins(:taxons).where("#{Taxon.table_name}.id" => ids)
      end

      def self.prepare_words(words)
        return [''] if words.blank?
        a = words.split(/[,\s]/).map(&:strip)
        a.any? ? a : ['']
      end

      def self.get_taxons(*ids_or_records_or_names)
        taxons = Taxon.table_name
        ids_or_records_or_names.flatten.map { |t|
          case t
          when Integer then Taxon.find_by(id: t)
          when ActiveRecord::Base then t
          when String
            Taxon.find_by(name: t) ||
            Taxon.where("#{taxons}.permalink LIKE ? OR #{taxons}.permalink = ?", "%/#{t}/", "#{t}/").first
          end
        }.compact.flatten.uniq
      end
    end
end
