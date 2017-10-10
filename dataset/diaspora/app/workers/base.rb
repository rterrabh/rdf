
module Workers
  class Base
    include Sidekiq::Worker
    sidekiq_options backtrace: (bt = AppConfig.environment.sidekiq.backtrace.get) && bt.to_i,
                    retry:  (rt = AppConfig.environment.sidekiq.retry.get) && rt.to_i

    include Diaspora::Logging

    def suppress_annoying_errors(&block)
      yield
    rescue Diaspora::ContactRequiredUnlessRequest,
           Diaspora::RelayableObjectWithoutParent,
           Diaspora::AuthorXMLAuthorMismatch,
           Diaspora::NonPublic,
           Diaspora::XMLNotParseable => e
      logger.warn "error on receive: #{e.class}"
    rescue ActiveRecord::RecordInvalid => e
      logger.warn "failed to save received object: #{e.record.errors.full_messages}"
      raise e unless %w(
        "already been taken"
        "is ignored by the post author"
      ).any? {|reason| e.message.include? reason }
    end
  end
end
