require_dependency 'new_post_manager'
require 'email/html_cleaner'

module Email

  class Receiver

    include ActionView::Helpers::NumberHelper

    class ProcessingError < StandardError; end
    class EmailUnparsableError < ProcessingError; end
    class EmptyEmailError < ProcessingError; end
    class UserNotFoundError < ProcessingError; end
    class UserNotSufficientTrustLevelError < ProcessingError; end
    class BadDestinationAddress < ProcessingError; end
    class TopicNotFoundError < ProcessingError; end
    class TopicClosedError < ProcessingError; end
    class AutoGeneratedEmailError < ProcessingError; end
    class EmailLogNotFound < ProcessingError; end
    class InvalidPost < ProcessingError; end

    attr_reader :body, :email_log

    def initialize(raw, opts=nil)
      @raw = raw
      @opts = opts || {}
    end

    def process
      raise EmptyEmailError if @raw.blank?

      message = Mail.new(@raw)

      body = parse_body message

      dest_info = {type: :invalid, obj: nil}
      message.to.each do |to_address|
        if dest_info[:type] == :invalid
          dest_info = check_address to_address
        end
      end

      raise BadDestinationAddress if dest_info[:type] == :invalid
      raise AutoGeneratedEmailError if message.header.to_s =~ /auto-generated/ || message.header.to_s =~ /auto-replied/

      @message = message
      @body = body

      if dest_info[:type] == :category
        raise BadDestinationAddress unless SiteSetting.email_in
        category = dest_info[:obj]
        @category_id = category.id
        @allow_strangers = category.email_in_allow_strangers

        user_email = @message.from.first
        @user = User.find_by_email(user_email)
        if @user.blank? && @allow_strangers

          wrap_body_in_quote user_email
          @user = Discourse.system_user
        end

        raise UserNotFoundError if @user.blank?
        raise UserNotSufficientTrustLevelError.new @user unless @allow_strangers || @user.has_trust_level?(TrustLevel[SiteSetting.email_in_min_trust.to_i])

        create_new_topic
      else
        @email_log = dest_info[:obj]

        raise EmailLogNotFound if @email_log.blank?
        raise TopicNotFoundError if Topic.find_by_id(@email_log.topic_id).nil?
        raise TopicClosedError if Topic.find_by_id(@email_log.topic_id).closed?

        create_reply
      end
    rescue Encoding::UndefinedConversionError, Encoding::InvalidByteSequenceError => e
      raise EmailUnparsableError.new(e)
    end

    def check_address(address)
      category = Category.find_by_email(address)
      return {type: :category, obj: category} if category

      regex = Regexp.escape SiteSetting.reply_by_email_address
      regex = regex.gsub(Regexp.escape('%{reply_key}'), "(.*)")
      regex = Regexp.new regex
      match = regex.match address
      if match && match[1].present?
        reply_key = match[1]
        email_log = EmailLog.for(reply_key)

        return {type: :reply, obj: email_log}
      end

      {type: :invalid, obj: nil}
    end

    def parse_body(message)
      body = select_body message
      encoding = body.encoding
      raise EmptyEmailError if body.strip.blank?

      body = discourse_email_trimmer body
      raise EmptyEmailError if body.strip.blank?

      body = EmailReplyParser.parse_reply body
      raise EmptyEmailError if body.strip.blank?

      body.force_encoding(encoding).encode("UTF-8")
    end

    def select_body(message)
      html = nil
      if message.multipart?
        html = fix_charset message.html_part
        text = fix_charset message.text_part

        if text
          return text
        end
      elsif message.content_type =~ /text\/html/
        html = fix_charset message
      end

      if html
        body = HtmlCleaner.new(html).output_html
      else
        body = fix_charset message
      end

      return body if @opts[:skip_sanity_check]

      if body =~ /Content\-Type\:/ || body =~ /multipart\/alternative/ || body =~ /text\/plain/
        raise EmptyEmailError
      end

      body
    end

    def fix_charset(object)
      return nil if object.nil?

      if object.charset
        object.body.decoded.force_encoding(object.charset.gsub(/utf8/i, "UTF-8")).encode("UTF-8").to_s
      else
        object.body.to_s
      end
    rescue
      nil
    end

    REPLYING_HEADER_LABELS = ['From', 'Sent', 'To', 'Subject', 'Reply To', 'Cc', 'Bcc', 'Date']
    REPLYING_HEADER_REGEX = Regexp.union(REPLYING_HEADER_LABELS.map { |lbl| "#{lbl}:" })

    def discourse_email_trimmer(body)
      lines = body.scrub.lines.to_a
      range_end = 0

      lines.each_with_index do |l, idx|
        break if l =~ /\A\s*\-{3,80}\s*\z/ ||
                 l =~ Regexp.new("\\A\\s*" + I18n.t('user_notifications.previous_discussion') + "\\s*\\Z") ||
                 (l =~ /via #{SiteSetting.title}(.*)\:$/) ||
                 (l =~ /\d{4}/ && l =~ /\d:\d\d/ && l =~ /\:$/) ||
                 (l =~ /On \w+ \d+,? \d+,?.*wrote:/)

        break if (0..2).all? { |off| lines[idx+off] =~ REPLYING_HEADER_REGEX }
        break if REPLYING_HEADER_LABELS.count { |lbl| l.include? lbl } >= 3

        range_end = idx
      end

      lines[0..range_end].join.strip
    end

    def wrap_body_in_quote(user_email)
      @body = "[quote=\"#{user_email}\"]
[/quote]"
    end

    private

    def create_reply
      create_post_with_attachments(@email_log.user,
                                   raw: @body,
                                   topic_id: @email_log.topic_id,
                                   reply_to_post_number: @email_log.post.post_number)
    end

    def create_new_topic
      result = create_post_with_attachments(@user,
                                          raw: @body,
                                          title: @message.subject,
                                          category: @category_id)

      topic_id = result.post.present? ? result.post.topic_id : nil
      EmailLog.create(
        email_type: "topic_via_incoming_email",
        to_address: @message.from.first, # pick from address because we want the user's email
        topic_id: topic_id,
        user_id: @user.id,
      )

      result
    end

    def create_post_with_attachments(user, post_opts={})
      options = {
        cooking_options: { traditional_markdown_linebreaks: true },
      }.merge(post_opts)

      raw = options[:raw]

      @message.attachments.each do |attachment|
        tmp = Tempfile.new("discourse-email-attachment")
        begin
          File.open(tmp.path, "w+b") { |f| f.write attachment.body.decoded }
          upload = Upload.create_for(user.id, tmp, attachment.filename, tmp.size)
          if upload && upload.errors.empty?
            raw << "\n#{attachment_markdown(upload)}\n"
          end
        ensure
          tmp.close!
        end
      end

      options[:raw] = raw

      create_post(user, options)
    end

    def attachment_markdown(upload)
      if FileHelper.is_image?(upload.original_filename)
        "<img src='#{upload.url}' width='#{upload.width}' height='#{upload.height}'>"
      else
        "<a class='attachment' href='#{upload.url}'>#{upload.original_filename}</a> (#{number_to_human_size(upload.filesize)})"
      end
    end

    def create_post(user, options)
      options[:via_email] = true
      options[:raw_email] = @raw

      manager = NewPostManager.new(user, options)
      result = manager.perform

      if result.errors.present?
        raise InvalidPost, result.errors.full_messages.join("\n")
      end

      result
    end

  end
end
