module ActiveAdmin
  module ScopeChain
    def scope_chain(scope, chain)
      if scope.scope_method
        #nodyna <send-84> <SD COMPLEX (change-prone variables)>
        chain.public_send scope.scope_method
      elsif scope.scope_block
        #nodyna <instance_exec-85> <IEX COMPLEX (block with parameters)>
        instance_exec chain, &scope.scope_block
      else
        chain
      end
    end
  end
end
