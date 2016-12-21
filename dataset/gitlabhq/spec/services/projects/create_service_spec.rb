require 'spec_helper'

describe Projects::CreateService do
  describe :create_by_user do
    before do
      @user = create :user
      @opts = {
        name: "GitLab",
        namespace: @user.namespace
      }
    end

    it 'creates services on Project creation' do
      project = create_project(@user, @opts)
      project.reload

      expect(project.services).not_to be_empty
    end

    context 'user namespace' do
      before do
        @project = create_project(@user, @opts)
      end

      it { expect(@project).to be_valid }
      it { expect(@project.owner).to eq(@user) }
      it { expect(@project.namespace).to eq(@user.namespace) }
    end

    context 'group namespace' do
      before do
        @group = create :group
        @group.add_owner(@user)

        @opts.merge!(namespace_id: @group.id)
        @project = create_project(@user, @opts)
      end

      it { expect(@project).to be_valid }
      it { expect(@project.owner).to eq(@group) }
      it { expect(@project.namespace).to eq(@group) }
    end

    context 'wiki_enabled creates repository directory' do
      context 'wiki_enabled true creates wiki repository directory' do
        before do
          @project = create_project(@user, @opts)
          @path = ProjectWiki.new(@project, @user).send(:path_to_repo)
        end

        it { expect(File.exists?(@path)).to be_truthy }
      end

      context 'wiki_enabled false does not create wiki repository directory' do
        before do
          @opts.merge!(wiki_enabled: false)
          @project = create_project(@user, @opts)
          @path = ProjectWiki.new(@project, @user).send(:path_to_repo)
        end

        it { expect(File.exists?(@path)).to be_falsey }
      end
    end

    context 'restricted visibility level' do
      before do
        stub_application_setting(restricted_visibility_levels: [Gitlab::VisibilityLevel::PUBLIC])

        @opts.merge!(
          visibility_level: Gitlab::VisibilityLevel.options['Public']
        )
      end

      it 'should not allow a restricted visibility level for non-admins' do
        project = create_project(@user, @opts)
        expect(project).to respond_to(:errors)
        expect(project.errors.messages).to have_key(:visibility_level)
        expect(project.errors.messages[:visibility_level].first).to(
          match('restricted by your GitLab administrator')
        )
      end

      it 'should allow a restricted visibility level for admins' do
        admin = create(:admin)
        project = create_project(admin, @opts)

        expect(project.errors.any?).to be(false)
        expect(project.saved?).to be(true)
      end
    end
  end

  def create_project(user, opts)
    Projects::CreateService.new(user, opts).execute
  end
end
