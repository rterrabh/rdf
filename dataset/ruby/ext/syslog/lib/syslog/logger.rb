require 'syslog'
require 'logger'


class Syslog::Logger
  class Formatter
    def call severity, time, progname, msg
      clean msg
    end

    private


    def clean message
      message = message.to_s.strip
      message.gsub!(/\e\[[0-9;]*m/, '') # remove useless ansi color codes
      return message
    end
  end


  VERSION = '2.1.0'


  LEVEL_MAP = {
    ::Logger::UNKNOWN => Syslog::LOG_ALERT,
    ::Logger::FATAL   => Syslog::LOG_ERR,
    ::Logger::ERROR   => Syslog::LOG_WARNING,
    ::Logger::WARN    => Syslog::LOG_NOTICE,
    ::Logger::INFO    => Syslog::LOG_INFO,
    ::Logger::DEBUG   => Syslog::LOG_DEBUG,
  }


  def self.syslog
    @@syslog
  end


  def self.syslog= syslog
    @@syslog = syslog
  end


  def self.make_methods meth
    #nodyna <const_get-1540> <CG COMPLEX (change-prone variable)>
    level = ::Logger.const_get(meth.upcase)
    #nodyna <eval-1541> <EV COMPLEX (method definition)>
    eval <<-EOM, nil, __FILE__, __LINE__ + 1
      def #{meth}(message = nil, &block)
        add(#{level}, message, &block)
      end

      def #{meth}?
        @level <= #{level}
      end
    EOM
  end







  Logger::Severity::constants.each do |severity|
    make_methods severity.downcase
  end


  attr_accessor :level

  attr_accessor :formatter


  attr_accessor :facility


  def initialize program_name = 'ruby', facility = nil
    @level = ::Logger::DEBUG
    @formatter = Formatter.new

    @@syslog ||= Syslog.open(program_name)

    @facility = (facility || @@syslog.facility)
  end


  def add severity, message = nil, progname = nil, &block
    severity ||= ::Logger::UNKNOWN
    @level <= severity and
      @@syslog.log( (LEVEL_MAP[severity] | @facility), '%s', formatter.call(severity, Time.now, progname, (message || block.call)) )
    true
  end
end
