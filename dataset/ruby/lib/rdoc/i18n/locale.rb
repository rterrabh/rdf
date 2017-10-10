
class RDoc::I18n::Locale

  @@locales = {} # :nodoc:

  class << self


    def [](locale_name)
      @@locales[locale_name] ||= new(locale_name)
    end


    def []=(locale_name, locale)
      @@locales[locale_name] = locale
    end

  end


  attr_reader :name


  def initialize(name)
    @name = name
    @messages = {}
  end


  def load(locale_directory)
    return false if @name.nil?

    po_file_candidates = [
      File.join(locale_directory, @name, 'rdoc.po'),
      File.join(locale_directory, "#{@name}.po"),
    ]
    po_file = po_file_candidates.find do |po_file_candidate|
      File.exist?(po_file_candidate)
    end
    return false unless po_file

    begin
      require 'gettext/po_parser'
      require 'gettext/mo'
    rescue LoadError
      warn('Need gettext gem for i18n feature:')
      warn('  gem install gettext')
      return false
    end

    po_parser = GetText::POParser.new
    messages = GetText::MO.new
    po_parser.report_warning = false
    po_parser.parse_file(po_file, messages)

    @messages.merge!(messages)

    true
  end


  def translate(message)
    @messages[message] || message
  end

end
