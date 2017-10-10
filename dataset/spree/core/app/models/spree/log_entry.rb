module Spree
  class LogEntry < Spree::Base
    belongs_to :source, polymorphic: true

    after_rollback :save_anyway

    def save_anyway
      log = Spree::LogEntry.new
      log.source  = source
      log.details = details
      log.save!
    end

    def parsed_details
      @details ||= YAML.load(details)
    end
  end
end
