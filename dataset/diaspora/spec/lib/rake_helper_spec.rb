
require 'spec_helper'
require 'rake_helpers'

include RakeHelpers
describe RakeHelpers do
  before do
    @csv = Rails.root.join('spec', 'fixtures', 'test.csv')
  end

  describe '#process_emails' do
    before do
      Devise.mailer.deliveries = []
      AppConfig.admins.account = FactoryGirl.create(:user).username
    end

    #nodyna <send-191> <not yet classified>
    it 'should send emails to each email' do
      expect(EmailInviter).to receive(:new).exactly(3).times.and_return(double.as_null_object)
      process_emails(@csv, 100, 1, false)
    end
  end
end

