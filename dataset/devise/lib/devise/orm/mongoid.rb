require 'orm_adapter/adapters/mongoid'

#nodyna <send-2742> <SD TRIVIAL (public methods)>
Mongoid::Document::ClassMethods.send :include, Devise::Models
