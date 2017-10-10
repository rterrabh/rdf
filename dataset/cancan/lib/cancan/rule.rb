module CanCan
  class Rule # :nodoc:
    attr_reader :base_behavior, :subjects, :actions, :conditions
    attr_writer :expanded_actions

    def initialize(base_behavior, action, subject, conditions, block)
      raise Error, "You are not able to supply a block with a hash of conditions in #{action} #{subject} ability. Use either one." if conditions.kind_of?(Hash) && !block.nil?
      @match_all = action.nil? && subject.nil?
      @base_behavior = base_behavior
      @actions = [action].flatten
      @subjects = [subject].flatten
      @conditions = conditions || {}
      @block = block
    end

    def relevant?(action, subject)
      subject = subject.values.first if subject.class == Hash
      @match_all || (matches_action?(action) && matches_subject?(subject))
    end

    def matches_conditions?(action, subject, extra_args)
      if @match_all
        call_block_with_all(action, subject, extra_args)
      elsif @block && !subject_class?(subject)
        @block.call(subject, *extra_args)
      elsif @conditions.kind_of?(Hash) && subject.class == Hash
        nested_subject_matches_conditions?(subject)
      elsif @conditions.kind_of?(Hash) && !subject_class?(subject)
        matches_conditions_hash?(subject)
      else
        @conditions.empty? ? true : @base_behavior
      end
    end

    def only_block?
      conditions_empty? && !@block.nil?
    end

    def only_raw_sql?
      @block.nil? && !conditions_empty? && !@conditions.kind_of?(Hash)
    end

    def conditions_empty?
      @conditions == {} || @conditions.nil?
    end

    def unmergeable?
      @conditions.respond_to?(:keys) && @conditions.present? &&
        (!@conditions.keys.first.kind_of? Symbol)
    end

    def associations_hash(conditions = @conditions)
      hash = {}
      conditions.map do |name, value|
        hash[name] = associations_hash(value) if value.kind_of? Hash
      end if conditions.kind_of? Hash
      hash
    end

    def attributes_from_conditions
      attributes = {}
      @conditions.each do |key, value|
        attributes[key] = value unless [Array, Range, Hash].include? value.class
      end if @conditions.kind_of? Hash
      attributes
    end

    private

    def subject_class?(subject)
      klass = (subject.kind_of?(Hash) ? subject.values.first : subject).class
      klass == Class || klass == Module
    end

    def matches_action?(action)
      @expanded_actions.include?(:manage) || @expanded_actions.include?(action)
    end

    def matches_subject?(subject)
      @subjects.include?(:all) || @subjects.include?(subject) || matches_subject_class?(subject)
    end

    def matches_subject_class?(subject)
      @subjects.any? { |sub| sub.kind_of?(Module) && (subject.kind_of?(sub) || subject.class.to_s == sub.to_s || subject.kind_of?(Module) && subject.ancestors.include?(sub)) }
    end

    def matches_conditions_hash?(subject, conditions = @conditions)
      if conditions.empty?
        true
      else
        if model_adapter(subject).override_conditions_hash_matching? subject, conditions
          model_adapter(subject).matches_conditions_hash? subject, conditions
        else
          conditions.all? do |name, value|
            if model_adapter(subject).override_condition_matching? subject, name, value
              model_adapter(subject).matches_condition? subject, name, value
            else
              #nodyna <send-2594> <not yet classified>
              attribute = subject.send(name)
              if value.kind_of?(Hash)
                if attribute.kind_of? Array
                  attribute.any? { |element| matches_conditions_hash? element, value }
                else
                  !attribute.nil? && matches_conditions_hash?(attribute, value)
                end
              elsif !value.is_a?(String) && value.kind_of?(Enumerable)
                value.include? attribute
              else
                attribute == value
              end
            end
          end
        end
      end
    end

    def nested_subject_matches_conditions?(subject_hash)
      parent, child = subject_hash.first
      matches_conditions_hash?(parent, @conditions[parent.class.name.downcase.to_sym] || {})
    end

    def call_block_with_all(action, subject, extra_args)
      if subject.class == Class
        @block.call(action, subject, nil, *extra_args)
      else
        @block.call(action, subject.class, subject, *extra_args)
      end
    end

    def model_adapter(subject)
      CanCan::ModelAdapters::AbstractAdapter.adapter_class(subject_class?(subject) ? subject : subject.class)
    end
  end
end
