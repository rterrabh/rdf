module API
  class Session < Grape::API
    post "/session" do
      auth = Gitlab::Auth.new
      user = auth.find(params[:email] || params[:login], params[:password])

      return unauthorized! unless user
      present user, with: Entities::UserLogin
    end
  end
end
