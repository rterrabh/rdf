require 'spec_helper'
describe Spree::Admin::ProductsController, :type => :controller do
  stub_authorization!

  it "cannot find a non-existent product" do
    spree_get :edit, :id => "non-existent-product"
    expect(response).to redirect_to(spree.admin_products_path)
    expect(flash[:error]).to eql("Product is not found")
  end
end


