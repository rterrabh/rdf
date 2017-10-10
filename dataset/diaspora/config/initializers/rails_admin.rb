if Rails.env.production?
  if defined?(WillPaginate)
    Kaminari.configure do |config|
      config.page_method_name = :per_page_kaminari
    end
  end
  RailsAdmin.config do |config|
    config.authorize_with do
      redirect_to main_app.root_path unless current_user.try(:admin?)
    end


    config.current_user_method { current_user } # auto-generated



    config.main_app_name = ['Diaspora', 'Admin']





    config.included_models = %w[
        AccountDeletion
        Aspect
        AspectMembership
        Block
        Comment
        Contact
        Conversation
        Invitation
        InvitationCode
        Like
        Location
        Mention
        Message
        OEmbedCache
        OpenGraphCache
        Person
        Photo
        Profile
        Pod
        Poll
        PollAnswer
        Post
        Profile
        Report
        Reshare
        Role
        Service
        StatusMessage
        User
        UserPreference
    ]






  end
end
