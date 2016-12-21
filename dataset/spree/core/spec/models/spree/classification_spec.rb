require 'spec_helper'

module Spree
  describe Classification, :type => :model do
    # Regression test for #3494
    it "cannot link the same taxon to the same product more than once" do
      product = create(:product)
      taxon = create(:taxon)
      add_taxon = lambda { product.taxons << taxon }
      expect(add_taxon).not_to raise_error
      expect(add_taxon).to raise_error(ActiveRecord::RecordInvalid)
    end

  end
end
