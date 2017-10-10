require 'rake/ext/core'

class String

  rake_extension("ext") do
    def ext(newext='')
      return self.dup if ['.', '..'].include? self
      newext = (newext =~ /^\./) ? newext : ("." + newext) if newext != ''
      self.chomp(File.extname(self)) << newext
    end
  end

  rake_extension("pathmap") do
    def pathmap_explode
      head, tail = File.split(self)
      return [self] if head == self
      return [tail] if head == '.' || tail == '/'
      return [head, tail] if head == '/'
      return head.pathmap_explode + [tail]
    end
    protected :pathmap_explode

    def pathmap_partial(n)
      dirs = File.dirname(self).pathmap_explode
      partial_dirs =
        if n > 0
          dirs[0...n]
        elsif n < 0
          dirs.reverse[0...-n].reverse
        else
          "."
        end
      File.join(partial_dirs)
    end
    protected :pathmap_partial

    def pathmap_replace(patterns, &block)
      result = self
      patterns.split(';').each do |pair|
        pattern, replacement = pair.split(',')
        pattern = Regexp.new(pattern)
        if replacement == '*' && block_given?
          result = result.sub(pattern, &block)
        elsif replacement
          result = result.sub(pattern, replacement)
        else
          result = result.sub(pattern, '')
        end
      end
      result
    end
    protected :pathmap_replace

    def pathmap(spec=nil, &block)
      return self if spec.nil?
      result = ''
      spec.scan(/%\{[^}]*\}-?\d*[sdpfnxX%]|%-?\d+d|%.|[^%]+/) do |frag|
        case frag
        when '%f'
          result << File.basename(self)
        when '%n'
          result << File.basename(self).ext
        when '%d'
          result << File.dirname(self)
        when '%x'
          result << File.extname(self)
        when '%X'
          result << self.ext
        when '%p'
          result << self
        when '%s'
          result << (File::ALT_SEPARATOR || File::SEPARATOR)
        when '%-'
        when '%%'
          result << "%"
        when /%(-?\d+)d/
          result << pathmap_partial($1.to_i)
        when /^%\{([^}]*)\}(\d*[dpfnxX])/
          patterns, operator = $1, $2
          result << pathmap('%' + operator).pathmap_replace(patterns, &block)
        when /^%/
          fail ArgumentError, "Unknown pathmap specifier #{frag} in '#{spec}'"
        else
          result << frag
        end
      end
      result
    end
  end

end
