module Spree
  class Address < Spree::Base
    require 'twitter_cldr'

    belongs_to :country, class_name: "Spree::Country"
    belongs_to :state, class_name: "Spree::State"

    has_many :shipments, inverse_of: :address

    validates :firstname, :lastname, :address1, :city, :country, presence: true
    validates :zipcode, presence: true, if: :require_zipcode?
    validates :phone, presence: true, if: :require_phone?

    validate :state_validate, :postal_code_validate

    alias_attribute :first_name, :firstname
    alias_attribute :last_name, :lastname


    self.whitelisted_ransackable_attributes = %w[firstname lastname company]

    def self.build_default
      country = Spree::Country.find(Spree::Config[:default_country_id]) rescue Spree::Country.first
      new(country: country)
    end

    def self.default(user = nil, kind = "bill")
      #nodyna <ID:send-106> <send VERY HIGH ex3>
      if user && user_address = user.send(:"#{kind}_address")
        user_address.clone
      else
        build_default
      end
    end

    # Can modify an address if it's not been used in an order (but checkouts controller has finer control)
    # def editable?
    #   new_record? || (shipments.empty? && checkouts.empty?)
    # end

    def full_name
      "#{firstname} #{lastname}".strip
    end

    def state_text
      state.try(:abbr) || state.try(:name) || state_name
    end

    def same_as?(other)
      return false if other.nil?
      attributes.except('id', 'updated_at', 'created_at') == other.attributes.except('id', 'updated_at', 'created_at')
    end

    alias same_as same_as?

    def to_s
      "#{full_name}: #{address1}"
    end

    def clone
      self.class.new(self.attributes.except('id', 'updated_at', 'created_at'))
    end

    def ==(other_address)
      self_attrs = self.attributes
      other_attrs = other_address.respond_to?(:attributes) ? other_address.attributes : {}

      [self_attrs, other_attrs].each { |attrs| attrs.except!('id', 'created_at', 'updated_at', 'order_id') }

      self_attrs == other_attrs
    end

    def empty?
      attributes.except('id', 'created_at', 'updated_at', 'order_id', 'country_id').all? { |_, v| v.nil? }
    end

    # Generates an ActiveMerchant compatible address hash
    def active_merchant_hash
      {
        name: full_name,
        address1: address1,
        address2: address2,
        city: city,
        state: state_text,
        zip: zipcode,
        country: country.try(:iso),
        phone: phone
      }
    end

    def require_phone?
      true
    end

    def require_zipcode?
      true
    end

    private
      def state_validate
        # Skip state validation without country (also required)
        # or when disabled by preference
        return if country.blank? || !Spree::Config[:address_requires_state]
        return unless country.states_required

        # ensure associated state belongs to country
        if state.present?
          if state.country == country
            self.state_name = nil #not required as we have a valid state and country combo
          else
            if state_name.present?
              self.state = nil
            else
              errors.add(:state, :invalid)
            end
          end
        end

        # ensure state_name belongs to country without states, or that it matches a predefined state name/abbr
        if state_name.present?
          if country.states.present?
            states = country.states.find_all_by_name_or_abbr(state_name)

            if states.size == 1
              self.state = states.first
              self.state_name = nil
            else
              errors.add(:state, :invalid)
            end
          end
        end

        # ensure at least one state field is populated
        errors.add :state, :blank if state.blank? && state_name.blank?
      end

      def postal_code_validate
        return if country.blank? || country.iso.blank? || !require_zipcode?
        return if !TwitterCldr::Shared::PostalCodes.territories.include?(country.iso.downcase.to_sym)

        postal_code = TwitterCldr::Shared::PostalCodes.for_territory(country.iso)
        errors.add(:zipcode, :invalid) if !postal_code.valid?(zipcode.to_s.strip)
      end
  end
end
