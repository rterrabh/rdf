
class CommonPasswords

  PASSWORD_FILE = File.join(Rails.root, 'lib', 'common_passwords', 'long-common-passwords.txt')
  LIST_KEY = 'discourse-common-passwords'

  @mutex = Mutex.new

  def self.common_password?(password)
    return false unless password.present?
    password_list.include?(password)
  end


  private

    class RedisPasswordList
      def include?(password)
        CommonPasswords.redis.sismember CommonPasswords::LIST_KEY, password
      end
    end

    def self.password_list
      @mutex.synchronize do
        load_passwords unless redis.scard(LIST_KEY) > 0
      end
      RedisPasswordList.new
    end

    def self.redis
      $redis.without_namespace
    end

    def self.load_passwords
      passwords = File.readlines(PASSWORD_FILE)
      passwords.map!(&:chomp).each do |pwd|
        redis.sadd LIST_KEY, pwd
      end
    rescue Errno::ENOENT
      Rails.logger.error "Common passwords file #{PASSWORD_FILE} is not found! Common password checking is skipped."
    end

end
