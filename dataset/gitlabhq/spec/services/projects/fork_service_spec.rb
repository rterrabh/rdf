require 'spec_helper'

describe Projects::ForkService do
  describe :fork_by_user do
    before do
      @from_namespace = create(:namespace)
      @from_user = create(:user, namespace: @from_namespace )
      @from_project = create(:project,
                             creator_id: @from_user.id,
                             namespace: @from_namespace,
                             star_count: 107,
                             description: 'wow such project')
      @to_namespace = create(:namespace)
      @to_user = create(:user, namespace: @to_namespace)
    end

    context 'fork project' do
      describe "successfully creates project in the user namespace" do
        let(:to_project) { fork_project(@from_project, @to_user) }

        it { expect(to_project.owner).to eq(@to_user) }
        it { expect(to_project.namespace).to eq(@to_user.namespace) }
        it { expect(to_project.star_count).to be_zero }
        it { expect(to_project.description).to eq(@from_project.description) }
      end
    end

    context 'fork project failure' do
      it "fails due to transaction failure" do
        @to_project = fork_project(@from_project, @to_user, false)
        expect(@to_project.errors).not_to be_empty
        expect(@to_project.errors[:base]).to include("Failed to fork repository via gitlab-shell")
      end
    end

    context 'project already exists' do
      it "should fail due to validation, not transaction failure" do
        @existing_project = create(:project, creator_id: @to_user.id, name: @from_project.name, namespace: @to_namespace)
        @to_project = fork_project(@from_project, @to_user)
        expect(@existing_project.persisted?).to be_truthy
        expect(@to_project.errors[:name]).to eq(['has already been taken'])
        expect(@to_project.errors[:path]).to eq(['has already been taken'])
      end
    end

    context 'GitLab CI is enabled' do
      it "calls fork registrator for CI" do
        @from_project.build_missing_services
        @from_project.gitlab_ci_service.update_attributes(active: true)

        expect(ForkRegistrationWorker).to receive(:perform_async)

        fork_project(@from_project, @to_user)
      end
    end
  end

  describe :fork_to_namespace do
    before do
      @group_owner = create(:user)
      @developer   = create(:user)
      @project     = create(:project, creator_id: @group_owner.id,
                                      star_count: 777,
                                      description: 'Wow, such a cool project!')
      @group = create(:group)
      @group.add_user(@group_owner, GroupMember::OWNER)
      @group.add_user(@developer,   GroupMember::DEVELOPER)
      @opts = { namespace: @group }
    end

    context 'fork project for group' do
      it 'group owner successfully forks project into the group' do
        to_project = fork_project(@project, @group_owner, true, @opts)
        expect(to_project.owner).to       eq(@group)
        expect(to_project.namespace).to   eq(@group)
        expect(to_project.name).to        eq(@project.name)
        expect(to_project.path).to        eq(@project.path)
        expect(to_project.description).to eq(@project.description)
        expect(to_project.star_count).to     be_zero
      end
    end

    context 'fork project for group when user not owner' do
      it 'group developer should fail to fork project into the group' do
        to_project = fork_project(@project, @developer, true, @opts)
        expect(to_project.errors[:namespace]).to eq(['is not valid'])
      end
    end

    context 'project already exists in group' do
      it 'should fail due to validation, not transaction failure' do
        existing_project = create(:project, name: @project.name,
                                            namespace: @group)
        to_project = fork_project(@project, @group_owner, true, @opts)
        expect(existing_project.persisted?).to be_truthy
        expect(to_project.errors[:name]).to eq(['has already been taken'])
        expect(to_project.errors[:path]).to eq(['has already been taken'])
      end
    end
  end

  def fork_project(from_project, user, fork_success = true, params = {})
    allow_any_instance_of(Gitlab::Shell).to receive(:fork_repository).and_return(fork_success)
    Projects::ForkService.new(from_project, user, params).execute
  end
end
