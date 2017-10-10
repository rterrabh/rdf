require 'spec_helper'

describe DisableEmailInterceptor do
  before do
    ActionMailer::Base.register_interceptor(DisableEmailInterceptor)
  end

  #nodyna <send-484> <not yet classified>
  it 'should not send emails' do
    allow(Gitlab.config.gitlab).to receive(:email_enabled).and_return(false)
    expect { deliver_mail }.not_to change(ActionMailer::Base.deliveries, :count)
  end

  after do
    #nodyna <class_variable_set-485> <not yet classified>
    Mail.class_variable_set(:@@delivery_interceptors, [])
  end

  def deliver_mail
    key = create :personal_key
    Notify.new_ssh_key_email(key.id)
  end
end
