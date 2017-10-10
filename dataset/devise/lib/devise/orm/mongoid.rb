require 'orm_adapter/adapters/mongoid'

#nodyna <send-2742> <not yet classified>
Mongoid::Document::ClassMethods.send :include, Devise::Models
