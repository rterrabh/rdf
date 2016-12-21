require 'paperclip/callbacks'
require 'paperclip/validators'
require 'paperclip/schema'

module Paperclip
  module Glue
    def self.included(base)
      base.extend ClassMethods
      #nodyna <ID:send-40> <send VERY LOW ex1>
      base.send :include, Callbacks
      #nodyna <ID:send-41> <send VERY LOW ex1>
      base.send :include, Validators
      #nodyna <ID:send-42> <send VERY LOW ex1>
      base.send :include, Schema

      locale_path = Dir.glob(File.dirname(__FILE__) + "/locales/*.{rb,yml}")
      I18n.load_path += locale_path unless I18n.load_path.include?(locale_path)
    end
  end
end
