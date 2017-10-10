
module Capybara

  module Helpers
    extend self

    def normalize_whitespace(text)
      text.to_s.gsub(/[[:space:]]+/, ' ').strip
    end

    def to_regexp(text)
      text.is_a?(Regexp) ? text : Regexp.new(Regexp.escape(normalize_whitespace(text)))
    end

    def inject_asset_host(html)
      if Capybara.asset_host && Nokogiri::HTML(html).css("base").empty?
        match = html.match(/<head[^<]*?>/)
        if match
          return html.clone.insert match.end(0), "<base href='#{Capybara.asset_host}' />"
        end
      end

      html
    end

    def matches_count?(count, options={})
      return (Integer(options[:count]) == count)     if options[:count]
      return false if options[:maximum] && (Integer(options[:maximum]) < count)
      return false if options[:minimum] && (Integer(options[:minimum]) > count)
      return false if options[:between] && !(options[:between] === count)
      return true
    end

    def expects_none?(options={})
      if [:count, :maximum, :minimum, :between].any? { |k| options.has_key? k }
        matches_count?(0,options)
      else
        false
      end
    end

    def failure_message(description, options={})
      message = "expected to find #{description}"
      if options[:count]
        message << " #{options[:count]} #{declension('time', 'times', options[:count])}"
      elsif options[:between]
        message << " between #{options[:between].first} and #{options[:between].last} times"
      elsif options[:maximum]
        message << " at most #{options[:maximum]} #{declension('time', 'times', options[:maximum])}"
      elsif options[:minimum]
        message << " at least #{options[:minimum]} #{declension('time', 'times', options[:minimum])}"
      end
      message
    end

    def declension(singular, plural, count)
      if count == 1
        singular
      else
        plural
      end
    end

    if defined?(Process::CLOCK_MONOTONIC)
      def monotonic_time
       Process.clock_gettime Process::CLOCK_MONOTONIC
      end
    else
      def monotonic_time
        Time.now.to_f
      end
    end
  end
end
