class Notify < ActionMailer::Base
  include ActionDispatch::Routing::PolymorphicRoutes

  include Emails::Issues
  include Emails::MergeRequests
  include Emails::Notes
  include Emails::Projects
  include Emails::Profile
  include Emails::Groups

  add_template_helper ApplicationHelper
  add_template_helper GitlabMarkdownHelper
  add_template_helper MergeRequestsHelper
  add_template_helper EmailsHelper

  attr_accessor :current_user
  helper_method :current_user, :can?

  default from: Proc.new { default_sender_address.format }
  default reply_to: Gitlab.config.gitlab.email_reply_to

  # Just send email with 2 seconds delay
  def self.delay
    delay_for(2.seconds)
  end

  def test_email(recipient_email, subject, body)
    mail(to: recipient_email,
         subject: subject,
         body: body.html_safe,
         content_type: 'text/html'
    )
  end

  # Splits "gitlab.corp.company.com" up into "gitlab.corp.company.com",
  # "corp.company.com" and "company.com".
  # Respects set tld length so "company.co.uk" won't match "somethingelse.uk"
  def self.allowed_email_domains
    domain_parts = Gitlab.config.gitlab.host.split(".")
    allowed_domains = []
    begin
      allowed_domains << domain_parts.join(".")
      domain_parts.shift
    end while domain_parts.length > ActionDispatch::Http::URL.tld_length

    allowed_domains
  end

  private

  # The default email address to send emails from
  def default_sender_address
    address = Mail::Address.new(Gitlab.config.gitlab.email_from)
    address.display_name = Gitlab.config.gitlab.email_display_name
    address
  end

  def can_send_from_user_email?(sender)
    sender_domain = sender.email.split("@").last
    self.class.allowed_email_domains.include?(sender_domain)
  end

  # Return an email address that displays the name of the sender.
  # Only the displayed name changes; the actual email address is always the same.
  def sender(sender_id, send_from_user_email = false)
    return unless sender = User.find(sender_id)

    address = default_sender_address
    address.display_name = sender.name

    if send_from_user_email && can_send_from_user_email?(sender)
      address.address = sender.email
    end

    address.format
  end

  # Look up a User by their ID and return their email address
  #
  # recipient_id - User ID
  #
  # Returns a String containing the User's email address.
  def recipient(recipient_id)
    @current_user = User.find(recipient_id)
    @current_user.notification_email
  end

  # Set the References header field
  #
  # local_part - The local part of the referenced message ID
  #
  def set_reference(local_part)
    headers["References"] = "<#{local_part}@#{Gitlab.config.gitlab.host}>"
  end

  # Formats arguments into a String suitable for use as an email subject
  #
  # extra - Extra Strings to be inserted into the subject
  #
  # Examples
  #
  #   >> subject('Lorem ipsum')
  #   => "Lorem ipsum"
  #
  #   # Automatically inserts Project name when @project is set
  #   >> @project = Project.last
  #   => #<Project id: 1, name: "Ruby on Rails", path: "ruby_on_rails", ...>
  #   >> subject('Lorem ipsum')
  #   => "Ruby on Rails | Lorem ipsum "
  #
  #   # Accepts multiple arguments
  #   >> subject('Lorem ipsum', 'Dolor sit amet')
  #   => "Lorem ipsum | Dolor sit amet"
  def subject(*extra)
    subject = ""
    subject << "#{@project.name} | " if @project
    subject << extra.join(' | ') if extra.present?
    subject
  end

  # Return a string suitable for inclusion in the 'Message-Id' mail header.
  #
  # The message-id is generated from the unique URL to a model object.
  def message_id(model)
    model_name = model.class.model_name.singular_route_key
    "<#{model_name}_#{model.id}@#{Gitlab.config.gitlab.host}>"
  end

  # Send an email that starts a new conversation thread,
  # with headers suitable for grouping by thread in email clients.
  #
  # See: mail_answer_thread
  def mail_new_thread(model, headers = {}, &block)
    headers['Message-ID'] = message_id(model)
    headers['X-GitLab-Project'] = "#{@project.name} | " if @project
    mail(headers, &block)
  end

  # Send an email that responds to an existing conversation thread,
  # with headers suitable for grouping by thread in email clients.
  #
  # For grouping emails by thread, email clients heuristics require the answers to:
  #
  #  * have a subject that begin by 'Re: '
  #  * have a 'In-Reply-To' or 'References' header that references the original 'Message-ID'
  #
  def mail_answer_thread(model, headers = {}, &block)
    headers['In-Reply-To'] = message_id(model)
    headers['References'] = message_id(model)
    headers['X-GitLab-Project'] = "#{@project.name} | " if @project

    if headers[:subject]
      headers[:subject].prepend('Re: ')
    end

    mail(headers, &block)
  end

  def can?
    Ability.abilities.allowed?(user, action, subject)
  end
end
