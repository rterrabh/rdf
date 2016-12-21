require 'spec_helper'
require Rails.root.join('spec', 'shared_behaviors', 'stream')

describe Stream::Multi do
  before do
    @stream = Stream::Multi.new(alice, :max_time => Time.now, :order => 'updated_at')
  end

  describe 'shared behaviors' do
    it_should_behave_like 'it is a stream'
  end

  describe "#posts" do
    it "calls EvilQuery::MultiStream with correct parameters" do
      expect(::EvilQuery::MultiStream).to receive(:new)
        .with(alice, 'updated_at', @stream.max_time,
              AppConfig.settings.community_spotlight.enable? &&
              alice.show_community_spotlight_in_stream?)
        .and_return(double.tap { |m| allow(m).to receive(:make_relation!)})
      @stream.posts
    end
  end

  describe '#publisher_opts' do
    it 'prefills, sets public, and autoexpands if welcome? is set' do
      prefill_text = "sup?"
      allow(@stream).to receive(:welcome?).and_return(true)
      allow(@stream).to receive(:publisher_prefill).and_return(prefill_text)
      #nodyna <ID:send-86> <send LOW ex4>
      expect(@stream.send(:publisher_opts)).to eq({:open => true,
                                               :prefill => prefill_text,
                                               :public => true})
    end

    it 'provides no opts if welcome? is not set' do
      prefill_text = "sup?"
      allow(@stream).to receive(:welcome?).and_return(false)
      #nodyna <ID:send-87> <send LOW ex4>
      expect(@stream.send(:publisher_opts)).to eq({})
    end
  end

  describe "#publisher_prefill" do
    before do
      @tag = ActsAsTaggableOn::Tag.find_or_create_by(name: "cats")
      @tag_following = alice.tag_followings.create(:tag_id => @tag.id)

      @stream = Stream::Multi.new(alice)
    end

    it 'returns includes new user hashtag' do
      #nodyna <ID:send-88> <send LOW ex4>
      expect(@stream.send(:publisher_prefill)).to match(/#NewHere/i)
    end

    it 'includes followed hashtags' do
      #nodyna <ID:send-89> <send LOW ex4>
      expect(@stream.send(:publisher_prefill)).to include("#cats")
    end

    context 'when invited by another user' do
      before do
        @user = FactoryGirl.create(:user, :invited_by => alice)
        @inviter = alice.person

        @stream = Stream::Multi.new(@user)
      end

      it 'includes a mention of the inviter' do
        mention = "@{#{@inviter.name} ; #{@inviter.diaspora_handle}}"
        #nodyna <ID:send-90> <send LOW ex4>
        expect(@stream.send(:publisher_prefill)).to include(mention)
      end
    end
  end

  describe "#welcome?" do
    before do
      @stream = Stream::Multi.new(alice)
    end

    it 'returns true if user is getting started' do
      alice.getting_started = true
      #nodyna <ID:send-91> <send LOW ex4>
      expect(@stream.send(:welcome?)).to be true
    end

    it 'returns false if user is getting started' do
      alice.getting_started = false
      #nodyna <ID:send-92> <send LOW ex4>
      expect(@stream.send(:welcome?)).to be false
    end
  end
end