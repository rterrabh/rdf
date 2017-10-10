module Vagrant
  module Util
    module ANSIEscapeCodeRemover
      def remove_ansi_escape_codes(text)
        matchers = [/\e\[\d*[ABCD]/,       # Matches things like \e[4D
                    /\e\[(\d*;)?\d*[HF]/,  # Matches \e[1;2H or \e[H
                    /\e\[(s|u|2J|K)/,      # Matches \e[s, \e[2J, etc.
                    /\e\[=\d*[hl]/,        # Matches \e[=24h
                    /\e\[\?[1-9][hl]/,     # Matches \e[?2h
                    /\e\[20[hl]/,          # Matches \e[20l]
                    /\e[DME78H]/,          # Matches \eD, \eH, etc.
                    /\e\[[0-2]?[JK]/,      # Matches \e[0J, \e[K, etc.
                    ]

        matchers.each do |matcher|
          text.gsub!(matcher, "")
        end

        text
      end
    end
  end
end
