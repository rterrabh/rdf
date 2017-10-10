require 'strscan'

module UTF8Util
  HIGH_BIT_RANGE = /[\x80-\xff]/

  def self.valid?(str)
    sc = StringScanner.new(str)

    while sc.skip_until(HIGH_BIT_RANGE)
      sc.pos -= 1

      if !sequence_length(sc)
        return false
      end
    end

    true
  end

  def self.clean!(str)
    sc = StringScanner.new(str)
    while sc.skip_until(HIGH_BIT_RANGE)
      pos = sc.pos = sc.pos-1

      if !sequence_length(sc)
        str[pos] = REPLACEMENT_CHAR
      end
    end

    str
  end

  def self.sequence_length(scanner)
    leader = scanner.get_byte[0]

    if (leader >> 5) == 0x6
      if check_next_sequence(scanner)
        return 2
      else
        scanner.pos -= 1
      end
    elsif (leader >> 4) == 0x0e
      if check_next_sequence(scanner)
        if check_next_sequence(scanner)
          return 3
        else
          scanner.pos -= 2
        end
      else
        scanner.pos -= 1
      end
    elsif (leader >> 3) == 0x1e
      if check_next_sequence(scanner)
        if check_next_sequence(scanner)
          if check_next_sequence(scanner)
            return 4
          else
            scanner.pos -= 3
          end
        else
          scanner.pos -= 2
        end
      else
        scanner.pos -= 1
      end
    end

    false
  end

  private

  def self.check_next_sequence(scanner)
    byte = scanner.get_byte[0]
    (byte >> 6) == 0x2
  end
end
