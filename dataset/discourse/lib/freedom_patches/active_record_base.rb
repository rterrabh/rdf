class ActiveRecord::Base

  def self.exec_sql(*args)
    conn = ActiveRecord::Base.connection
    #nodyna <send-350> <SD COMPLEX (private methods)>
    sql = ActiveRecord::Base.send(:sanitize_sql_array, args)
    conn.raw_connection.exec(sql)
  end

  def self.exec_sql_row_count(*args)
    exec_sql(*args).cmd_tuples
  end

  def self.sql_fragment(*sql_array)
    #nodyna <send-351> <SD COMPLEX (private methods)>
    ActiveRecord::Base.send(:sanitize_sql_array, sql_array)
  end

  def exec_sql(*args)
    ActiveRecord::Base.exec_sql(*args)
  end


  def self.retry_lock_error(retries=5, &block)
    begin
      yield
    rescue ActiveRecord::StatementInvalid => e
      if e.message =~ /deadlock detected/ && (retries.nil? || retries > 0)
        retry_lock_error(retries ? retries - 1 : nil, &block)
      else
        raise e
      end
    end
  end

  def exec_sql_row_count(*args)
    exec_sql(*args).cmd_tuples
  end

end
