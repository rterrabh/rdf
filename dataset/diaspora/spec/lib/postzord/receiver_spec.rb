
require "spec_helper"

describe Postzord::Receiver do
  before do
    @receiver = Postzord::Receiver.new
  end

  describe "#perform!" do
    before do
      allow(@receiver).to receive(:receive!).and_return(true)
    end

    it "calls receive!" do
      expect(@receiver).to receive(:receive!)
      @receiver.perform!
    end
  end

  describe "#author_does_not_match_xml_author?" do
    before do
      #nodyna <instance_variable_set-165> <IVS MODERATE (private access)>
      @receiver.instance_variable_set(:@author, alice.person)
      allow(@receiver).to receive(:xml_author).and_return(alice.diaspora_handle)
    end

    it "should return false if the author matches" do
      allow(@receiver).to receive(:xml_author).and_return(alice.diaspora_handle)
      #nodyna <send-166> <SD EASY (private methods)>
      expect(@receiver.send(:author_does_not_match_xml_author?)).to be_falsey
    end

    it "should return true if the author does not match" do
      allow(@receiver).to receive(:xml_author).and_return(bob.diaspora_handle)
      #nodyna <send-167> <SD EASY (private methods)>
      expect(@receiver.send(:author_does_not_match_xml_author?)).to be_truthy
    end
  end

  describe "#relayable_without_parent?" do
    before do
      #nodyna <instance_variable_set-168> <IVS MODERATE (private access)>
      @receiver.instance_variable_set(:@author, alice.person)
    end

    it "should return false if object is not relayable" do
      #nodyna <instance_variable_set-169> <IVS MODERATE (private access)>
      @receiver.instance_variable_set(:@object, nil)
      #nodyna <send-170> <SD EASY (private methods)>
      expect(@receiver.send(:relayable_without_parent?)).to be_falsey
    end

    context "if object is relayable" do
      before do
        @comment = bob.build_comment(text: "yo", post: FactoryGirl.create(:status_message))
        #nodyna <instance_variable_set-171> <IVS MODERATE (private access)>
        @receiver.instance_variable_set(:@object, @comment)
      end

      it "should return false if object has parent" do
        #nodyna <send-172> <SD EASY (private methods)>
        expect(@receiver.send(:relayable_without_parent?)).to be_falsey
      end

      it "should return true if object has no parent" do
        @comment.parent = nil
        #nodyna <send-173> <SD EASY (private methods)>
        expect(@receiver.send(:relayable_without_parent?)).to be_truthy
      end
    end
  end
end
