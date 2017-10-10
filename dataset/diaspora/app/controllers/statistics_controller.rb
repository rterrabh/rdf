
class StatisticsController < ApplicationController
  respond_to :html, :json

  def statistics
    @statistics = StatisticsPresenter.new
    respond_to do |format|
      format.json { render json: @statistics }
      format.all
    end
  end
end
