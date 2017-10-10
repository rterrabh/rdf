

module YAML # :nodoc:
  if defined? ::Syck
    remove_const :Syck rescue nil

    Syck = ::Syck

  elsif defined? YAML::Yecht
    Syck = YAML::Yecht

  elsif !defined? YAML::Syck
    module Syck
      class DefaultKey # :nodoc:
      end
    end
  end

  module Syck
    class DefaultKey
      remove_method :to_s rescue nil

      def to_s
        '='
      end
    end
  end

  SyntaxError = Error unless defined? SyntaxError
end

if !defined?(Syck)
  Syck = YAML::Syck
end


module Gem
  remove_const :SyckDefaultKey if const_defined? :SyckDefaultKey

  SyckDefaultKey = YAML::Syck::DefaultKey
end

