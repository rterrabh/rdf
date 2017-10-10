module ArJdbcMySQL #:nodoc:
  class Error < StandardError #:nodoc:
    attr_accessor :error_number, :sql_state

    def initialize msg
      super
      @error_number = nil
      @sql_state    = nil
    end

    alias_method :errno, :error_number
    alias_method :error, :message
  end
end
