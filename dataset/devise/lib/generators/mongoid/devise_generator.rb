require 'rails/generators/named_base'
require 'generators/devise/orm_helpers'

module Mongoid
  module Generators
    class DeviseGenerator < Rails::Generators::NamedBase
      include Devise::Generators::OrmHelpers

      def generate_model
        invoke "mongoid:model", [name] unless model_exists? && behavior == :invoke
      end

      def inject_field_types
        inject_into_file model_path, migration_data, after: "include Mongoid::Document\n" if model_exists?
      end

      def inject_devise_content
        inject_into_file model_path, model_contents, after: "include Mongoid::Document\n" if model_exists?
      end

      def migration_data
<<RUBY
  field :email,              type: String, default: ""
  field :encrypted_password, type: String, default: ""

  field :reset_password_token,   type: String
  field :reset_password_sent_at, type: Time

  field :remember_created_at, type: Time

  field :sign_in_count,      type: Integer, default: 0
  field :current_sign_in_at, type: Time
  field :last_sign_in_at,    type: Time
  field :current_sign_in_ip, type: String
  field :last_sign_in_ip,    type: String


RUBY
      end
    end
  end
end
