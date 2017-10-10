require 'spec_helper'

module Spree
  class DelegateBelongsToStubModel < Spree::Base
    self.table_name = "spree_payment_methods"
    belongs_to :product
    delegate_belongs_to :product, :name
  end

  describe DelegateBelongsToStubModel do
    context "model has column attr delegated to associated object" do
      it "doesnt touch the associated object" do
        expect(subject).not_to receive(:product)
        subject.name
      end
    end
  end 
end
