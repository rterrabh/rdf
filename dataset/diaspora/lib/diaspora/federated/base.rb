



module Diaspora
  module Federated
    module Base
      include Diaspora::Logging

      def self.included(model)
        #nodyna <instance_eval-211> <IEV EASY (private access)>
        model.instance_eval do
          include ROXML
          include Diaspora::Federated::Base::InstanceMethods
        end
      end

      module InstanceMethods
        def to_diaspora_xml
          xml = to_xml
          ::Logging::Logger["XMLLogger"].debug "to_xml: #{xml}"
          <<-XML
          <XML>
            <post>#{xml}</post>
          </XML>
          XML
        end

        def x(input)
          input.to_s.to_xs
        end

        def subscribers(user)
          raise 'You must override subscribers in order to enable federation on this model'
        end

        def receive(user, person)
          raise 'You must override receive in order to enable federation on this model'
        end

        def after_dispatch(sender)
        end
      end
    end
  end
end
