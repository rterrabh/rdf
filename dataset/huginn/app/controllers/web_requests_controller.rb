
class WebRequestsController < ApplicationController
  skip_before_action :verify_authenticity_token
  skip_before_action :authenticate_user!

  def handle_request
    user = User.find_by_id(params[:user_id])
    if user
      agent = user.agents.find_by_id(params[:agent_id])
      if agent
        content, status, content_type = agent.trigger_web_request(params.except(:action, :controller, :agent_id, :user_id, :format), request.method_symbol.to_s, request.format.to_s)
        if content.is_a?(String)
          render :text => content, :status => status || 200, :content_type => content_type || 'text/plain'
        elsif content.is_a?(Hash)
          render :json => content, :status => status || 200
        else
          head(status || 200)
        end
      else
        render :text => "agent not found", :status => 404
      end
    else
      render :text => "user not found", :status => 404
    end
  end

  def update_location
    if user = User.find_by_id(params[:user_id])
      secret = params[:secret]
      user.agents.of_type(Agents::UserLocationAgent).each { |agent|
        if agent.options[:secret] == secret
          agent.trigger_web_request(params.except(:action, :controller, :user_id, :format), request.method_symbol.to_s, request.format.to_s)
        end
      }
      render :text => "ok"
    else
      render :text => "user not found", :status => :not_found
    end
  end
end
