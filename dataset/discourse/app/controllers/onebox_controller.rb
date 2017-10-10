require_dependency 'oneboxer'

class OneboxController < ApplicationController

  def show
    result = Oneboxer.preview(params[:url], invalidate_oneboxes: params[:refresh] == 'true')
    result.strip! if result.present?

    if result.blank?
      render nothing: true, status: 404
    else
      render text: result
    end
  end

end
