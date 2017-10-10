module Participable
  extend ActiveSupport::Concern

  module ClassMethods
    def participant(*attrs)
      participant_attrs.concat(attrs.map(&:to_s))
    end

    def participant_attrs
      @participant_attrs ||= []
    end
  end

  def participants(current_user = self.author, project = self.project)
    participants = self.class.participant_attrs.flat_map do |attr|
      meth = method(attr)

      value =
        if meth.arity == 1 || meth.arity == -1
          meth.call(current_user)
        else
          meth.call
        end

      participants_for(value, current_user, project)
    end.compact.uniq

    if project
      participants.select! do |user|
        user.can?(:read_project, project)
      end
    end

    participants
  end

  private

  def participants_for(value, current_user = nil, project = nil)
    case value
    when User
      [value]
    when Enumerable, ActiveRecord::Relation
      value.flat_map { |v| participants_for(v, current_user, project) }
    when Participable
      value.participants(current_user, project)
    end
  end
end
