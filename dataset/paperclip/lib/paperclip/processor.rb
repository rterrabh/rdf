module Paperclip
  class Processor
    attr_accessor :file, :options, :attachment

    def initialize file, options = {}, attachment = nil
      @file = file
      @options = options
      @attachment = attachment
    end

    def make
    end

    def self.make file, options = {}, attachment = nil
      new(file, options, attachment).make
    end

    def convert(arguments = "", local_options = {})
      Paperclip.run('convert', arguments, local_options)
    end

    def identify(arguments = "", local_options = {})
      Paperclip.run('identify', arguments, local_options)
    end
  end
end
