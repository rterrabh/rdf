module ActiveRecord
  module Associations
    class HasOneThroughAssociation < HasOneAssociation #:nodoc:
      include ThroughAssociation

      def replace(record)
        create_through_record(record)
        self.target = record
      end

      private

        def create_through_record(record)
          ensure_not_nested

          through_proxy  = owner.association(through_reflection.name)
          #nodyna <send-897> <SD TRIVIAL (public methods)>
          through_record = through_proxy.send(:load_target)

          if through_record && !record
            through_record.destroy
          elsif record
            attributes = construct_join_attributes(record)

            if through_record
              through_record.update(attributes)
            elsif owner.new_record?
              through_proxy.build(attributes)
            else
              through_proxy.create(attributes)
            end
          end
        end
    end
  end
end
