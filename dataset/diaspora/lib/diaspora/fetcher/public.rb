module Diaspora; module Fetcher; class Public
  include Diaspora::Logging

  Status_Initial = 0
  Status_Running = 1
  Status_Fetched = 2
  Status_Processed = 3
  Status_Done = 4
  Status_Failed  = 5
  Status_Unfetchable = 6

  def self.queue_for(person)
    Workers::FetchPublicPosts.perform_async(person.diaspora_handle) unless person.fetch_status > Status_Initial
  end

  def fetch! diaspora_id
    @person = Person.by_account_identifier diaspora_id
    return unless qualifies_for_fetching?

    begin
      retrieve_and_process_posts
    rescue => e
      set_fetch_status Public::Status_Failed
      raise e
    end

    set_fetch_status Public::Status_Done
  end

  private
    def qualifies_for_fetching?
      raise ActiveRecord::RecordNotFound unless @person.present?
      return false if @person.fetch_status == Public::Status_Unfetchable

      if @person.local?
        set_fetch_status Public::Status_Unfetchable
        return false
      end

      return false if @person.fetch_status > Public::Status_Initial

      @person.remote? &&
      @person.fetch_status == Public::Status_Initial
    end

    def retrieve_and_process_posts
      begin
        retrieve_posts
      rescue => e
        logger.error "unable to retrieve public posts for #{@person.diaspora_handle}"
        raise e
      end

      begin
        process_posts
      rescue => e
        logger.error "unable to process public posts for #{@person.diaspora_handle}"
        raise e
      end
    end

    def retrieve_posts
      set_fetch_status Public::Status_Running

      logger.info "fetching public posts for #{@person.diaspora_handle}"

      resp = Faraday.get("#{@person.url}people/#{@person.guid}/stream") do |req|
        req.headers['Accept'] = 'application/json'
        req.headers['User-Agent'] = 'diaspora-fetcher'
      end

      logger.debug "fetched response: #{resp.body.to_s[0..250]}"

      @data = JSON.parse resp.body
      set_fetch_status Public::Status_Fetched
    end

    def process_posts
      @data.each do |post|
        next unless validate(post)

        logger.info "saving fetched post (#{post['guid']}) to database"

        logger.debug "post: #{post.to_s[0..250]}"

        StatusMessage.skip_callback :create, :set_guid

        entry = StatusMessage.diaspora_initialize(
          :author => @person,
          :public => true
        )
        entry.assign_attributes({
          :guid => post['guid'],
          :text => post['text'],
          :provider_display_name => post['provider_display_name'],
          :created_at => ActiveSupport::TimeZone.new('UTC').parse(post['created_at']).to_datetime,
          :interacted_at => ActiveSupport::TimeZone.new('UTC').parse(post['interacted_at']).to_datetime,
          :frame_name => post['frame_name']
        })
        entry.save

        StatusMessage.set_callback :create, :set_guid

      end
      set_fetch_status Public::Status_Processed
    end

    def set_fetch_status status
      return if @person.nil?

      @person.fetch_status = status
      @person.save
    end

    def validate post
      check_existing(post) && check_author(post) && check_public(post) && check_type(post)
    end

    def check_existing post
      new_post = (Post.find_by_guid(post['guid']).blank?)

      logger.warn "a post with that guid (#{post['guid']}) already exists" unless new_post

      new_post
    end

    def check_author post
      guid = post['author']['guid']
      equal = (guid == @person.guid)

      unless equal
        logger.warn "the author (#{guid}) does not match the person currently being processed (#{@person.guid})"
      end

      equal
    end

    def check_public post
      ispublic = (post['public'] == true)

      logger.warn "the post (#{post['guid']}) is not public, this is not intended..." unless ispublic

      ispublic
    end

    def check_type post
      type_ok = (post['post_type'] == "StatusMessage")

      logger.warn "the post (#{post['guid']}) has a type, which cannot be handled (#{post['post_type']})" unless type_ok

      type_ok
    end
end; end; end
