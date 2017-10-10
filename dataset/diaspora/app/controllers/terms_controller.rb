
class TermsController < ApplicationController

  respond_to :html, :mobile

  def index
    partial_dir = Rails.root.join('app', 'views', 'terms')
    if partial_dir.join('terms.haml').exist? ||
        partial_dir.join('terms.erb').exist?
      render :terms
    else
      render :default
    end
  end

end
