module ActiveAdmin
  module ScopeChain
    # Scope an ActiveRecord::Relation chain
    #
    # Example:
    #   scope_chain(Scope.new(:published), Article)
    #   # => Article.published
    #
    # @param scope The <ActiveAdmin::Scope> we want to scope on
    # @param chain The ActiveRecord::Relation chain or ActiveRecord::Base class to scope
    # @return <ActiveRecord::Relation or ActiveRecord::Base> The scoped relation chain
    #
    def scope_chain(scope, chain)
      if scope.scope_method
        #nodyna <ID:send-55> <send VERY HIGH ex3>
        chain.public_send scope.scope_method
      elsif scope.scope_block
        #nodyna <ID:instance_exec-17> <instance_exec VERY HIGH ex2>
        instance_exec chain, &scope.scope_block
      else
        chain
      end
    end
  end
end
