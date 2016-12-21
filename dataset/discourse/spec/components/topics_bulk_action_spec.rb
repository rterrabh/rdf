require 'spec_helper'
require_dependency 'topics_bulk_action'

describe TopicsBulkAction do

  describe "dismiss_posts" do
    it "dismisses posts" do
      post1 = create_post
      p = create_post(topic_id: post1.topic_id)
      create_post(topic_id: post1.topic_id)

      PostDestroyer.new(Fabricate(:admin), p).destroy

      TopicsBulkAction.new(post1.user, [post1.topic_id], type: 'dismiss_posts').perform!

      tu = TopicUser.find_by(user_id: post1.user_id, topic_id: post1.topic_id)

      expect(tu.last_read_post_number).to eq(3)
      expect(tu.highest_seen_post_number).to eq(3)
    end
  end

  describe "invalid operation" do
    let(:user) { Fabricate.build(:user) }

    it "raises an error with an invalid operation" do
      tba = TopicsBulkAction.new(user, [1], type: 'rm_root')
      expect { tba.perform! }.to raise_error(Discourse::InvalidParameters)
    end
  end

  describe "change_category" do
    let(:topic) { Fabricate(:topic) }
    let(:category) { Fabricate(:category) }

    context "when the user can edit the topic" do
      it "changes the category and returns the topic_id" do
        tba = TopicsBulkAction.new(topic.user, [topic.id], type: 'change_category', category_id: category.id)
        topic_ids = tba.perform!
        expect(topic_ids).to eq([topic.id])
        topic.reload
        expect(topic.category).to eq(category)
      end
    end

    context "when the user can't edit the topic" do
      it "doesn't change the category" do
        Guardian.any_instance.expects(:can_edit?).returns(false)
        tba = TopicsBulkAction.new(topic.user, [topic.id], type: 'change_category', category_id: category.id)
        topic_ids = tba.perform!
        expect(topic_ids).to eq([])
        topic.reload
        expect(topic.category).not_to eq(category)
      end
    end
  end

  describe "reset_read" do
    let(:topic) { Fabricate(:topic) }

    it "delegates to PostTiming.destroy_for" do
      tba = TopicsBulkAction.new(topic.user, [topic.id], type: 'reset_read')
      PostTiming.expects(:destroy_for).with(topic.user_id, [topic.id])
      topic_ids = tba.perform!
    end
  end

  describe "delete" do
    let(:topic) { Fabricate(:topic) }
    let(:moderator) { Fabricate(:moderator) }

    it "deletes the topic" do
      tba = TopicsBulkAction.new(moderator, [topic.id], type: 'delete')
      tba.perform!
      topic.reload
      expect(topic).to be_trashed
    end
  end

  describe "change_notification_level" do
    let(:topic) { Fabricate(:topic) }

    context "when the user can see the topic" do
      it "updates the notification level" do
        tba = TopicsBulkAction.new(topic.user, [topic.id], type: 'change_notification_level', notification_level_id: 2)
        topic_ids = tba.perform!
        expect(topic_ids).to eq([topic.id])
        expect(TopicUser.get(topic, topic.user).notification_level).to eq(2)
      end
    end

    context "when the user can't see the topic" do
      it "doesn't change the level" do
        Guardian.any_instance.expects(:can_see?).returns(false)
        tba = TopicsBulkAction.new(topic.user, [topic.id], type: 'change_notification_level', notification_level_id: 2)
        topic_ids = tba.perform!
        expect(topic_ids).to eq([])
        expect(TopicUser.get(topic, topic.user)).to be_blank
      end
    end
  end

  describe "close" do
    let(:topic) { Fabricate(:topic) }

    context "when the user can moderate the topic" do
      it "closes the topic and returns the topic_id" do
        Guardian.any_instance.expects(:can_moderate?).returns(true)
        Guardian.any_instance.expects(:can_create?).returns(true)
        tba = TopicsBulkAction.new(topic.user, [topic.id], type: 'close')
        topic_ids = tba.perform!
        expect(topic_ids).to eq([topic.id])
        topic.reload
        expect(topic).to be_closed
      end
    end

    context "when the user can't edit the topic" do
      it "doesn't close the topic" do
        Guardian.any_instance.expects(:can_moderate?).returns(false)
        tba = TopicsBulkAction.new(topic.user, [topic.id], type: 'close')
        topic_ids = tba.perform!
        expect(topic_ids).to be_blank
        topic.reload
        expect(topic).not_to be_closed
      end
    end
  end

  describe "archive" do
    let(:topic) { Fabricate(:topic) }

    context "when the user can moderate the topic" do
      it "archives the topic and returns the topic_id" do
        Guardian.any_instance.expects(:can_moderate?).returns(true)
        Guardian.any_instance.expects(:can_create?).returns(true)
        tba = TopicsBulkAction.new(topic.user, [topic.id], type: 'archive')
        topic_ids = tba.perform!
        expect(topic_ids).to eq([topic.id])
        topic.reload
        expect(topic).to be_archived
      end
    end

    context "when the user can't edit the topic" do
      it "doesn't archive the topic" do
        Guardian.any_instance.expects(:can_moderate?).returns(false)
        tba = TopicsBulkAction.new(topic.user, [topic.id], type: 'archive')
        topic_ids = tba.perform!
        expect(topic_ids).to be_blank
        topic.reload
        expect(topic).not_to be_archived
      end
    end
  end
end
