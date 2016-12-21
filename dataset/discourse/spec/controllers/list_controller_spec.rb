require 'spec_helper'

describe ListController do

  # we need some data
  before do
    @user = Fabricate(:coding_horror)
    @post = Fabricate(:post, user: @user)

    # forces tests down some code paths
    SiteSetting.stubs(:top_menu).returns('latest,-video|new|unread|categories|category/beer')
  end

  describe 'titles for crawler layout' do
    it 'has no title for the default URL' do
      xhr :get, Discourse.anonymous_filters[0], _escaped_fragment_: 'true'
      expect(assigns(:title)).to be_blank
    end

    it 'has a title for non-default URLs' do
      xhr :get, Discourse.anonymous_filters[1], _escaped_fragment_: 'true'
      expect(assigns(:title)).to be_present
    end
  end

  describe 'indexes' do

    (Discourse.anonymous_filters - [:categories]).each do |filter|
      context "#{filter}" do
        before { xhr :get, filter }
        it { is_expected.to respond_with(:success) }
      end
    end

    Discourse.logged_in_filters.each do |filter|
      context "#{filter}" do
        it { expect { xhr :get, filter }.to raise_error(Discourse::NotLoggedIn) }
      end
    end

    it 'allows users to filter on a set of topic ids' do
      p = create_post

      xhr :get, :latest, format: :json, topic_ids: "#{p.topic_id}"
      expect(response).to be_success
      parsed = JSON.parse(response.body)
      expect(parsed["topic_list"]["topics"].length).to eq(1)
    end

  end

  describe 'RSS feeds' do

    Discourse.feed_filters.each do |filter|

      it 'renders RSS' do
        get "#{filter}_feed", format: :rss
        expect(response).to be_success
        expect(response.content_type).to eq('application/rss+xml')
      end

    end

  end

  context 'category' do

    context 'in a category' do
      let(:category) { Fabricate(:category) }

      context 'without access to see the category' do
        before do
          Guardian.any_instance.expects(:can_see?).with(category).returns(false)
          xhr :get, :category_latest, category: category.slug
        end

        it { is_expected.not_to respond_with(:success) }
      end

      context 'with access to see the category' do
        before do
          xhr :get, :category_latest, category: category.slug
        end

        it { is_expected.to respond_with(:success) }
      end

      context 'with a link that includes an id' do
        before do
          xhr :get, :category_latest, category: "#{category.id}-#{category.slug}"
        end

        it { is_expected.to respond_with(:success) }
      end

      context 'another category exists with a number at the beginning of its name' do
        # One category has another category's id at the beginning of its name
        let!(:other_category) { Fabricate(:category, name: "#{category.id} name") }

        before do
          xhr :get, :category_latest, category: other_category.slug
        end

        it { is_expected.to respond_with(:success) }

        it 'uses the correct category' do
          expect(assigns(:category)).to eq(other_category)
        end
      end

      context 'a child category' do
        let(:sub_category) { Fabricate(:category, parent_category_id: category.id) }

        context 'when parent and child are requested' do
          before do
            xhr :get, :category_latest, parent_category: category.slug, category: sub_category.slug
          end

          it { is_expected.to respond_with(:success) }
        end

        context 'when child is requested with the wrong parent' do
          before do
            xhr :get, :category_latest, parent_category: 'not_the_right_slug', category: sub_category.slug
          end

          it { is_expected.not_to respond_with(:success) }
        end

      end

      describe 'feed' do
        it 'renders RSS' do
          get :category_feed, category: category.slug, format: :rss
          expect(response).to be_success
          expect(response.content_type).to eq('application/rss+xml')
        end
      end
    end
  end

  describe "topics_by" do
    let!(:user) { log_in }

    it "should respond with a list" do
      xhr :get, :topics_by, username: @user.username
      expect(response).to be_success
    end
  end

  context "private_messages" do
    let!(:user) { log_in }

    it "raises an error when can_see_private_messages? is false " do
      Guardian.any_instance.expects(:can_see_private_messages?).returns(false)
      xhr :get, :private_messages, username: @user.username
      expect(response).to be_forbidden
    end

    it "succeeds when can_see_private_messages? is false " do
      Guardian.any_instance.expects(:can_see_private_messages?).returns(true)
      xhr :get, :private_messages, username: @user.username
      expect(response).to be_success
    end
  end

  context "private_messages_sent" do
    let!(:user) { log_in }

    it "raises an error when can_see_private_messages? is false " do
      Guardian.any_instance.expects(:can_see_private_messages?).returns(false)
      xhr :get, :private_messages_sent, username: @user.username
      expect(response).to be_forbidden
    end

    it "succeeds when can_see_private_messages? is false " do
      Guardian.any_instance.expects(:can_see_private_messages?).returns(true)
      xhr :get, :private_messages_sent, username: @user.username
      expect(response).to be_success
    end
  end

  context "private_messages_unread" do
    let!(:user) { log_in }

    it "raises an error when can_see_private_messages? is false " do
      Guardian.any_instance.expects(:can_see_private_messages?).returns(false)
      xhr :get, :private_messages_unread, username: @user.username
      expect(response).to be_forbidden
    end

    it "succeeds when can_see_private_messages? is false " do
      Guardian.any_instance.expects(:can_see_private_messages?).returns(true)
      xhr :get, :private_messages_unread, username: @user.username
      expect(response).to be_success
    end
  end

  context 'read' do
    it 'raises an error when not logged in' do
      expect { xhr :get, :read }.to raise_error(Discourse::NotLoggedIn)
    end

    context 'when logged in' do
      before do
        log_in_user(@user)
        xhr :get, :read
      end

      it { is_expected.to respond_with(:success) }
    end
  end

  describe "best_periods_for" do

    it "returns yearly for more than 180 days" do
      expect(ListController.best_periods_for(nil)).to eq([:yearly])
      expect(ListController.best_periods_for(180.days.ago)).to eq([:yearly])
    end

    it "includes monthly when less than 180 days and more than 35 days" do
      (35...180).each do |date|
        expect(ListController.best_periods_for(date.days.ago)).to eq([:monthly, :yearly])
      end
    end

    it "includes weekly when less than 35 days and more than 8 days" do
      (8...35).each do |date|
        expect(ListController.best_periods_for(date.days.ago)).to eq([:weekly, :monthly, :yearly])
      end
    end

    it "includes daily when less than 8 days" do
      (0...8).each do |date|
        expect(ListController.best_periods_for(date.days.ago)).to eq([:daily, :weekly, :monthly, :yearly])
      end
    end

  end

end
