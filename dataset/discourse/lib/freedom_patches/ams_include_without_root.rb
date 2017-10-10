module ActiveModel
  class Serializer
    def include!(name, options={})
      unique_values =
        if hash = options[:hash]
          if @options[:hash] == hash
            @options[:unique_values] ||= {}
          else
            {}
          end
        else
          hash = @options[:hash]
          @options[:unique_values] ||= {}
        end

      node = options[:node] ||= @node
      value = options[:value]

      if options[:include] == nil
        if @options.key?(:include)
          options[:include] = @options[:include].include?(name)
        elsif @options.include?(:exclude)
          options[:include] = !@options[:exclude].include?(name)
        end
      end

      association_class =
        if klass = _associations[name]
          klass
        elsif value.respond_to?(:to_ary)
          Associations::HasMany
        else
          Associations::HasOne
        end

      association = association_class.new(name, self, options)

      if association.embed_ids?
        node[association.key] = association.serialize_ids

        if association.embed_in_root? && hash.nil?
        elsif association.embed_in_root? && association.embeddable?
          merge_association hash, association.root, association.serializables, unique_values
        end
      elsif association.embed_objects?
        node[association.key] = association.serialize
      end
    end
  end
end
