module CanCan

  module Ability
    def can?(action, subject, *extra_args)
      match = relevant_rules_for_match(action, subject).detect do |rule|
        rule.matches_conditions?(action, subject, extra_args)
      end
      match ? match.base_behavior : false
    end

    def cannot?(*args)
      !can?(*args)
    end

    def can(action = nil, subject = nil, conditions = nil, &block)
      rules << Rule.new(true, action, subject, conditions, block)
    end

    def cannot(action = nil, subject = nil, conditions = nil, &block)
      rules << Rule.new(false, action, subject, conditions, block)
    end

    def alias_action(*args)
      target = args.pop[:to]
      validate_target(target)
      aliased_actions[target] ||= []
      aliased_actions[target] += args
    end

    def validate_target(target)
      raise Error, "You can't specify target (#{target}) as alias because it is real action name" if aliased_actions.values.flatten.include? target
    end

    def aliased_actions
      @aliased_actions ||= default_alias_actions
    end

    def clear_aliased_actions
      @aliased_actions = {}
    end

    def model_adapter(model_class, action)
      adapter_class = ModelAdapters::AbstractAdapter.adapter_class(model_class)
      adapter_class.new(model_class, relevant_rules_for_query(action, model_class))
    end

    def authorize!(action, subject, *args)
      message = nil
      if args.last.kind_of?(Hash) && args.last.has_key?(:message)
        message = args.pop[:message]
      end
      if cannot?(action, subject, *args)
        message ||= unauthorized_message(action, subject)
        raise AccessDenied.new(message, action, subject)
      end
      subject
    end

    def unauthorized_message(action, subject)
      keys = unauthorized_message_keys(action, subject)
      variables = {:action => action.to_s}
      variables[:subject] = (subject.class == Class ? subject : subject.class).to_s.underscore.humanize.downcase
      message = I18n.translate(nil, variables.merge(:scope => :unauthorized, :default => keys + [""]))
      message.blank? ? nil : message
    end

    def attributes_for(action, subject)
      attributes = {}
      relevant_rules(action, subject).map do |rule|
        attributes.merge!(rule.attributes_from_conditions) if rule.base_behavior
      end
      attributes
    end

    def has_block?(action, subject)
      relevant_rules(action, subject).any?(&:only_block?)
    end

    def has_raw_sql?(action, subject)
      relevant_rules(action, subject).any?(&:only_raw_sql?)
    end

    def merge(ability)
      #nodyna <send-2621> <SD EASY (private methods)>
      ability.send(:rules).each do |rule|
        rules << rule.dup
      end
      self
    end

    private

    def unauthorized_message_keys(action, subject)
      subject = (subject.class == Class ? subject : subject.class).name.underscore unless subject.kind_of? Symbol
      [subject, :all].map do |try_subject|
        [aliases_for_action(action), :manage].flatten.map do |try_action|
          :"#{try_action}.#{try_subject}"
        end
      end.flatten
    end

    def expand_actions(actions)
      actions.map do |action|
        aliased_actions[action] ? [action, *expand_actions(aliased_actions[action])] : action
      end.flatten
    end

    def aliases_for_action(action)
      results = [action]
      aliased_actions.each do |aliased_action, actions|
        results += aliases_for_action(aliased_action) if actions.include? action
      end
      results
    end

    def rules
      @rules ||= []
    end

    def relevant_rules(action, subject)
      rules.reverse.select do |rule|
        rule.expanded_actions = expand_actions(rule.actions)
        rule.relevant? action, subject
      end
    end

    def relevant_rules_for_match(action, subject)
      relevant_rules(action, subject).each do |rule|
        if rule.only_raw_sql?
          raise Error, "The can? and cannot? call cannot be used with a raw sql 'can' definition. The checking code cannot be determined for #{action.inspect} #{subject.inspect}"
        end
      end
    end

    def relevant_rules_for_query(action, subject)
      relevant_rules(action, subject).each do |rule|
        if rule.only_block?
          raise Error, "The accessible_by call cannot be used with a block 'can' definition. The SQL cannot be determined for #{action.inspect} #{subject.inspect}"
        end
      end
    end

    def default_alias_actions
      {
        :read => [:index, :show],
        :create => [:new],
        :update => [:edit],
      }
    end
  end
end
