module Gitlab
  module BitbucketImport
    class KeyDeleter
      attr_reader :project, :current_user, :client

      def initialize(project)
        @project = project
        @current_user = project.creator
        @client = Client.new(current_user.bitbucket_access_token, current_user.bitbucket_access_token_secret)
      end

      def execute
        return false unless BitbucketImport.public_key.present?
        
        client.delete_deploy_key(project.import_source, BitbucketImport.public_key)

        true
      rescue
        false
      end
    end
  end
end
