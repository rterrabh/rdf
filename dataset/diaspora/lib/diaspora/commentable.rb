
module Diaspora
  module Commentable
    def self.included(model)
      #nodyna <instance_eval-219> <IEV COMPLEX (private access)>
      model.instance_eval do
        has_many :comments, :as => :commentable, :dependent => :destroy
      end
    end

  def last_three_comments
    return [] if self.comments_count == 0
    self.comments.order('created_at DESC').limit(3).includes(:author => :profile).reverse
  end

    def update_comments_counter
      self.class.where(:id => self.id).
        update_all(:comments_count => self.comments.count)
    end

  end
end
