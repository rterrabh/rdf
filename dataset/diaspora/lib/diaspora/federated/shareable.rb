
module Diaspora
  module Federated
    module Shareable
      def self.included(model)
        #nodyna <instance_eval-210> <IEV COMPLEX (private access)>
        model.instance_eval do
          include Diaspora::Federated::Base
          include Diaspora::Federated::Shareable::InstanceMethods
          include Diaspora::Guid

          xml_attr :diaspora_handle
          xml_attr :public
          xml_attr :created_at
        end
      end

      module InstanceMethods
        include Diaspora::Logging
        def diaspora_handle
          read_attribute(:diaspora_handle) || author.diaspora_handle
        end

        def diaspora_handle=(author_handle)
          self.author = Person.where(diaspora_handle: author_handle).first
          write_attribute(:diaspora_handle, author_handle)
        end

        def receive(user, person)
          local_shareable = persisted_shareable
          if local_shareable
            receive_persisted(user, person, local_shareable) if verify_persisted_shareable(local_shareable)
          else
            receive_non_persisted(user, person)
          end
        end

        def receive_public
          local_shareable = persisted_shareable
          if local_shareable
            update_existing_sharable(local_shareable) if verify_persisted_shareable(local_shareable)
          else
            save!
          end
        end

        def subscribers(user)
          if self.public?
            user.contact_people
          else
            user.people_in_aspects(user.aspects_with_shareable(self.class, id))
          end
        end

        protected

        def persisted_shareable
          self.class.where(guid: guid).first
        end

        def verify_persisted_shareable(persisted_shareable)
          return true if persisted_shareable.author_id == author_id
          logger.warn "event=receive payload_type=#{self.class} update=true status=abort " \
                      "sender=#{diaspora_handle} reason='update not from shareable owner' guid=#{guid}"
          false
        end

        def receive_persisted(user, person, shareable)
          known_shareable = user.find_visible_shareable_by_id(self.class.base_class, guid, key: :guid)
          if known_shareable
            update_existing_sharable(known_shareable)
          else
            receive_shareable_visibility(user, person, shareable)
          end
        end

        def update_existing_sharable(shareable)
          if shareable.mutable?
            shareable.update_attributes(attributes.except("id"))
            logger.info "event=receive payload_type=#{self.class} update=true status=complete " \
                        "sender=#{diaspora_handle} guid=#{shareable.guid}"
          else
            logger.warn "event=receive payload_type=#{self.class} update=true status=abort " \
                        "sender=#{diaspora_handle} reason=immutable guid=#{shareable.guid}"
          end
        end

        def receive_shareable_visibility(user, person, shareable)
          user.contact_for(person).receive_shareable(shareable)
          user.notify_if_mentioned(shareable)
          logger.info "event=receive payload_type=#{self.class} status=complete " \
                      "sender=#{diaspora_handle} receiver=#{person.diaspora_handle} guid=#{shareable.guid}"
        end

        def receive_non_persisted(user, person)
          if save
            logger.info "event=receive payload_type=#{self.class} status=complete sender=#{diaspora_handle} " \
                        "guid=#{guid}"
            receive_shareable_visibility(user, person, self)
          else
            logger.warn "event=receive payload_type=#{self.class} status=abort sender=#{diaspora_handle} " \
                        "reason=#{errors.full_messages} guid=#{guid}"
          end
        rescue ActiveRecord::RecordNotUnique => e
          logger.info "event=receive payload_type=#{self.class} status=retry sender=#{diaspora_handle} guid=#{guid}"
          local_shareable = persisted_shareable
          raise e unless local_shareable
          receive_shareable_visibility(user, person, local_shareable) if verify_persisted_shareable(local_shareable)
        end
      end
    end
  end
end
