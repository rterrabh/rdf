
require 'spec_helper'

describe Postzord::Receiver::Private do

  before do
    @alices_post = alice.build_post(:status_message, :text => "hey", :aspect_ids => [alice.aspects.first.id])
    @salmon_xml = alice.salmon(@alices_post).xml_for(bob.person)
  end

  describe '.initialize' do
    it 'valid for local' do
      expect(Webfinger).not_to receive(:new)
      expect(Salmon::EncryptedSlap).not_to receive(:from_xml)

      zord = Postzord::Receiver::Private.new(bob, :person => alice.person, :object => @alices_post)
      #nodyna <instance_variable_get-154> <not yet classified>
      expect(zord.instance_variable_get(:@user)).not_to be_nil
      #nodyna <instance_variable_get-155> <not yet classified>
      expect(zord.instance_variable_get(:@author)).not_to be_nil
      #nodyna <instance_variable_get-156> <not yet classified>
      expect(zord.instance_variable_get(:@object)).not_to be_nil
    end

    it 'valid for remote' do
      salmon_double = double()
      web_double = double()
      expect(web_double).to receive(:fetch).and_return true
      expect(salmon_double).to receive(:author_id).and_return(true)
      expect(Salmon::EncryptedSlap).to receive(:from_xml).with(@salmon_xml, bob).and_return(salmon_double)
      expect(Webfinger).to receive(:new).and_return(web_double)

      zord = Postzord::Receiver::Private.new(bob, :salmon_xml => @salmon_xml)
      #nodyna <instance_variable_get-157> <not yet classified>
      expect(zord.instance_variable_get(:@user)).not_to be_nil
      #nodyna <instance_variable_get-158> <not yet classified>
      expect(zord.instance_variable_get(:@author)).not_to be_nil
      #nodyna <instance_variable_get-159> <not yet classified>
      expect(zord.instance_variable_get(:@salmon_xml)).not_to be_nil
    end
  end

  describe '#receive!' do
    before do
      @zord = Postzord::Receiver::Private.new(bob, :salmon_xml => @salmon_xml)
      #nodyna <instance_variable_get-160> <not yet classified>
      @salmon = @zord.instance_variable_get(:@salmon)
    end

    context "does not parse and receive" do
      it "if the salmon author does not exist" do
        #nodyna <instance_variable_set-161> <not yet classified>
        @zord.instance_variable_set(:@author, nil)
        expect(@zord).not_to receive(:parse_and_receive)
        @zord.receive!
      end

      it "if the author does not match the signature" do
        #nodyna <instance_variable_set-162> <not yet classified>
        @zord.instance_variable_set(:@author, FactoryGirl.create(:person))
        expect(@zord).not_to receive(:parse_and_receive)
        @zord.receive!
      end
    end

    it 'parses the salmon object' do
      expect(Diaspora::Parser).to receive(:from_xml).with(@salmon.parsed_data).and_return(@alices_post)
      @zord.receive!
    end
  end

  describe 'receive_object' do
    before do
      @zord = Postzord::Receiver::Private.new(bob, :person => alice.person, :object => @alices_post)
      #nodyna <instance_variable_get-163> <not yet classified>
      @salmon = @zord.instance_variable_get(:@salmon)
    end

    it 'calls Notification.notify if object responds to notification_type' do
      cm = Comment.new
      allow(cm).to receive(:receive).and_return(cm)

      expect(Notification).to receive(:notify).with(bob, cm, alice.person)
      zord = Postzord::Receiver::Private.new(bob, :person => alice.person, :object => cm)
      zord.receive_object
    end

    it 'does not call Notification.notify if object does not respond to notification_type' do
      expect(Notification).not_to receive(:notify)
      @zord.receive_object
    end

    it 'calls receive on @object' do
      #nodyna <instance_variable_get-164> <not yet classified>
      obj = expect(@zord.instance_variable_get(:@object)).to receive(:receive)
      @zord.receive_object
    end
  end
end
