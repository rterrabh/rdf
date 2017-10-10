module ActiveSupport
  module Multibyte
    module Unicode

      extend self

      NORMALIZATION_FORMS = [:c, :kc, :d, :kd]

      UNICODE_VERSION = '7.0.0'

      attr_accessor :default_normalization_form
      @default_normalization_form = :kc

      HANGUL_SBASE = 0xAC00
      HANGUL_LBASE = 0x1100
      HANGUL_VBASE = 0x1161
      HANGUL_TBASE = 0x11A7
      HANGUL_LCOUNT = 19
      HANGUL_VCOUNT = 21
      HANGUL_TCOUNT = 28
      HANGUL_NCOUNT = HANGUL_VCOUNT * HANGUL_TCOUNT
      HANGUL_SCOUNT = 11172
      HANGUL_SLAST = HANGUL_SBASE + HANGUL_SCOUNT
      HANGUL_JAMO_FIRST = 0x1100
      HANGUL_JAMO_LAST = 0x11FF

      WHITESPACE = [
        (0x0009..0x000D).to_a, # White_Space # Cc   [5] <control-0009>..<control-000D>
        0x0020,                # White_Space # Zs       SPACE
        0x0085,                # White_Space # Cc       <control-0085>
        0x00A0,                # White_Space # Zs       NO-BREAK SPACE
        0x1680,                # White_Space # Zs       OGHAM SPACE MARK
        (0x2000..0x200A).to_a, # White_Space # Zs  [11] EN QUAD..HAIR SPACE
        0x2028,                # White_Space # Zl       LINE SEPARATOR
        0x2029,                # White_Space # Zp       PARAGRAPH SEPARATOR
        0x202F,                # White_Space # Zs       NARROW NO-BREAK SPACE
        0x205F,                # White_Space # Zs       MEDIUM MATHEMATICAL SPACE
        0x3000,                # White_Space # Zs       IDEOGRAPHIC SPACE
      ].flatten.freeze

      LEADERS_AND_TRAILERS = WHITESPACE + [65279] # ZERO-WIDTH NO-BREAK SPACE aka BOM

      def self.codepoints_to_pattern(array_of_codepoints) #:nodoc:
        array_of_codepoints.collect{ |e| [e].pack 'U*' }.join('|')
      end
      TRAILERS_PAT = /(#{codepoints_to_pattern(LEADERS_AND_TRAILERS)})+\Z/u
      LEADERS_PAT = /\A(#{codepoints_to_pattern(LEADERS_AND_TRAILERS)})+/u

      def in_char_class?(codepoint, classes)
        classes.detect { |c| database.boundary[c] === codepoint } ? true : false
      end

      def unpack_graphemes(string)
        codepoints = string.codepoints.to_a
        unpacked = []
        pos = 0
        marker = 0
        eoc = codepoints.length
        while(pos < eoc)
          pos += 1
          previous = codepoints[pos-1]
          current = codepoints[pos]
          if (
              ( previous == database.boundary[:cr] and current == database.boundary[:lf] ) or
              ( database.boundary[:l] === previous and in_char_class?(current, [:l,:v,:lv,:lvt]) ) or
              ( in_char_class?(previous, [:lv,:v]) and in_char_class?(current, [:v,:t]) ) or
              ( in_char_class?(previous, [:lvt,:t]) and database.boundary[:t] === current ) or
              (database.boundary[:extend] === current)
            )
          else
            unpacked << codepoints[marker..pos-1]
            marker = pos
          end
        end
        unpacked
      end

      def pack_graphemes(unpacked)
        unpacked.flatten.pack('U*')
      end

      def reorder_characters(codepoints)
        length = codepoints.length- 1
        pos = 0
        while pos < length do
          cp1, cp2 = database.codepoints[codepoints[pos]], database.codepoints[codepoints[pos+1]]
          if (cp1.combining_class > cp2.combining_class) && (cp2.combining_class > 0)
            codepoints[pos..pos+1] = cp2.code, cp1.code
            pos += (pos > 0 ? -1 : 1)
          else
            pos += 1
          end
        end
        codepoints
      end

      def decompose(type, codepoints)
        codepoints.inject([]) do |decomposed, cp|
          if HANGUL_SBASE <= cp and cp < HANGUL_SLAST
            sindex = cp - HANGUL_SBASE
            ncp = [] # new codepoints
            ncp << HANGUL_LBASE + sindex / HANGUL_NCOUNT
            ncp << HANGUL_VBASE + (sindex % HANGUL_NCOUNT) / HANGUL_TCOUNT
            tindex = sindex % HANGUL_TCOUNT
            ncp << (HANGUL_TBASE + tindex) unless tindex == 0
            decomposed.concat ncp
          elsif (ncp = database.codepoints[cp].decomp_mapping) and (!database.codepoints[cp].decomp_type || type == :compatibility)
            decomposed.concat decompose(type, ncp.dup)
          else
            decomposed << cp
          end
        end
      end

      def compose(codepoints)
        pos = 0
        eoa = codepoints.length - 1
        starter_pos = 0
        starter_char = codepoints[0]
        previous_combining_class = -1
        while pos < eoa
          pos += 1
          lindex = starter_char - HANGUL_LBASE
          if 0 <= lindex and lindex < HANGUL_LCOUNT
            vindex = codepoints[starter_pos+1] - HANGUL_VBASE rescue vindex = -1
            if 0 <= vindex and vindex < HANGUL_VCOUNT
              tindex = codepoints[starter_pos+2] - HANGUL_TBASE rescue tindex = -1
              if 0 <= tindex and tindex < HANGUL_TCOUNT
                j = starter_pos + 2
                eoa -= 2
              else
                tindex = 0
                j = starter_pos + 1
                eoa -= 1
              end
              codepoints[starter_pos..j] = (lindex * HANGUL_VCOUNT + vindex) * HANGUL_TCOUNT + tindex + HANGUL_SBASE
            end
            starter_pos += 1
            starter_char = codepoints[starter_pos]
          else
            current_char = codepoints[pos]
            current = database.codepoints[current_char]
            if current.combining_class > previous_combining_class
              if ref = database.composition_map[starter_char]
                composition = ref[current_char]
              else
                composition = nil
              end
              unless composition.nil?
                codepoints[starter_pos] = composition
                starter_char = composition
                codepoints.delete_at pos
                eoa -= 1
                pos -= 1
                previous_combining_class = -1
              else
                previous_combining_class = current.combining_class
              end
            else
              previous_combining_class = current.combining_class
            end
            if current.combining_class == 0
              starter_pos = pos
              starter_char = codepoints[pos]
            end
          end
        end
        codepoints
      end

      if '<3'.respond_to?(:scrub) && !defined?(Rubinius)
        def tidy_bytes(string, force = false)
          return string if string.empty?
          return recode_windows1252_chars(string) if force
          string.scrub { |bad| recode_windows1252_chars(bad) }
        end
      else
        def tidy_bytes(string, force = false)
          return string if string.empty?
          return recode_windows1252_chars(string) if force

          reader = Encoding::Converter.new(Encoding::UTF_8, Encoding::UTF_16LE)

          source = string.dup
          out = ''.force_encoding(Encoding::UTF_16LE)

          loop do
            reader.primitive_convert(source, out)
            _, _, _, error_bytes, _ = reader.primitive_errinfo
            break if error_bytes.nil?
            out << error_bytes.encode(Encoding::UTF_16LE, Encoding::Windows_1252, invalid: :replace, undef: :replace)
          end

          reader.finish

          out.encode!(Encoding::UTF_8)
        end
      end

      def normalize(string, form=nil)
        form ||= @default_normalization_form
        codepoints = string.codepoints.to_a
        case form
          when :d
            reorder_characters(decompose(:canonical, codepoints))
          when :c
            compose(reorder_characters(decompose(:canonical, codepoints)))
          when :kd
            reorder_characters(decompose(:compatibility, codepoints))
          when :kc
            compose(reorder_characters(decompose(:compatibility, codepoints)))
          else
            raise ArgumentError, "#{form} is not a valid normalization variant", caller
        end.pack('U*')
      end

      def downcase(string)
        apply_mapping string, :lowercase_mapping
      end

      def upcase(string)
        apply_mapping string, :uppercase_mapping
      end

      def swapcase(string)
        apply_mapping string, :swapcase_mapping
      end

      class Codepoint
        attr_accessor :code, :combining_class, :decomp_type, :decomp_mapping, :uppercase_mapping, :lowercase_mapping

        def initialize
          @combining_class = 0
          @uppercase_mapping = 0
          @lowercase_mapping = 0
        end

        def swapcase_mapping
          uppercase_mapping > 0 ? uppercase_mapping : lowercase_mapping
        end
      end

      class UnicodeDatabase
        ATTRIBUTES = :codepoints, :composition_exclusion, :composition_map, :boundary, :cp1252

        attr_writer(*ATTRIBUTES)

        def initialize
          @codepoints = Hash.new(Codepoint.new)
          @composition_exclusion = []
          @composition_map = {}
          @boundary = {}
          @cp1252 = {}
        end

        ATTRIBUTES.each do |attr_name|
          #nodyna <class_eval-1104> <not yet classified>
          class_eval(<<-EOS, __FILE__, __LINE__ + 1)
            def #{attr_name}     # def codepoints
              load               #   load
              @#{attr_name}      #   @codepoints
            end                  # end
          EOS
        end

        def load
          begin
            @codepoints, @composition_exclusion, @composition_map, @boundary, @cp1252 = File.open(self.class.filename, 'rb') { |f| Marshal.load f.read }
          rescue => e
            raise IOError.new("Couldn't load the Unicode tables for UTF8Handler (#{e.message}), ActiveSupport::Multibyte is unusable")
          end

          @boundary.each do |k,_|
            #nodyna <instance_eval-1105> <IEV COMPLEX (method definition)>
            @boundary[k].instance_eval do
              def ===(other)
                detect { |i| i === other } ? true : false
              end
            end if @boundary[k].kind_of?(Array)
          end

          class << self
            attr_reader(*ATTRIBUTES)
          end
        end

        def self.dirname
          File.dirname(__FILE__) + '/../values/'
        end

        def self.filename
          File.expand_path File.join(dirname, "unicode_tables.dat")
        end
      end

      private

      def apply_mapping(string, mapping) #:nodoc:
        database.codepoints
        string.each_codepoint.map do |codepoint|
          cp = database.codepoints[codepoint]
          #nodyna <send-1106> <SD MODERATE (change-prone variables)>
          if cp and (ncp = cp.send(mapping)) and ncp > 0
            ncp
          else
            codepoint
          end
        end.pack('U*')
      end

      def recode_windows1252_chars(string)
        string.encode(Encoding::UTF_8, Encoding::Windows_1252, invalid: :replace, undef: :replace)
      end

      def database
        @database ||= UnicodeDatabase.new
      end
    end
  end
end
