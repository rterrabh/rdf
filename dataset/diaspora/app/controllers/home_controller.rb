
class HomeController < ApplicationController
  def show
    partial_dir = Rails.root.join("app", "views", "home")
    if user_signed_in?
      redirect_to stream_path
    elsif request.format == :mobile
      if partial_dir.join("_show.mobile.haml").exist? ||
         partial_dir.join("_show.mobile.erb").exist? ||
         partial_dir.join("_show.haml").exist?
        render :show
      else
        redirect_to user_session_path
      end
    elsif partial_dir.join("_show.html.haml").exist? ||
          partial_dir.join("_show.html.erb").exist? ||
          partial_dir.join("_show.haml").exist?
      render :show
    else
      render :default,
             layout: "application"
    end
  end

  def toggle_mobile
    if session[:mobile_view].nil?
      session[:mobile_view] = true
    else
      session[:mobile_view] = !session[:mobile_view]
    end

    redirect_to :back
  end
end
