module Jobs
  class PostAlert < Jobs::Base

    def execute(args)
      if post = Post.find_by(id: args[:post_id])
        PostAlerter.post_created(post) if post.topic
      end
    end

  end
end

