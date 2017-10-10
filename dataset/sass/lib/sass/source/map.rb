module Sass::Source
  class Map
    class Mapping < Struct.new(:input, :output)
      def inspect
        "#{input.inspect} => #{output.inspect}"
      end
    end

    attr_reader :data

    def initialize
      @data = []
    end

    def add(input, output)
      @data.push(Mapping.new(input, output))
    end

    def shift_output_lines(delta)
      return if delta == 0
      @data.each do |m|
        m.output.start_pos.line += delta
        m.output.end_pos.line += delta
      end
    end

    def shift_output_offsets(delta)
      return if delta == 0
      @data.each do |m|
        break if m.output.start_pos.line > 1
        m.output.start_pos.offset += delta
        m.output.end_pos.offset += delta if m.output.end_pos.line > 1
      end
    end

    def to_json(options)
      css_uri, css_path, sourcemap_path =
        options[:css_uri], options[:css_path], options[:sourcemap_path]
      unless css_uri || (css_path && sourcemap_path)
        raise ArgumentError.new("Sass::Source::Map#to_json requires either " \
          "the :css_uri option or both the :css_path and :soucemap_path options.")
      end
      css_path &&= Sass::Util.pathname(Sass::Util.absolute_path(css_path))
      sourcemap_path &&= Sass::Util.pathname(Sass::Util.absolute_path(sourcemap_path))
      css_uri ||= Sass::Util.file_uri_from_path(
        Sass::Util.relative_path_from(css_path, sourcemap_path.dirname))

      result = "{\n"
      write_json_field(result, "version", 3, true)

      source_uri_to_id = {}
      id_to_source_uri = {}
      id_to_contents = {} if options[:type] == :inline
      next_source_id = 0
      line_data = []
      segment_data_for_line = []

      previous_target_line = nil
      previous_target_offset = 1
      previous_source_line = 1
      previous_source_offset = 1
      previous_source_id = 0

      @data.each do |m|
        file, importer = m.input.file, m.input.importer

        if options[:type] == :inline
          source_uri = file
        else
          sourcemap_dir = sourcemap_path && sourcemap_path.dirname.to_s
          sourcemap_dir = nil if options[:type] == :file
          source_uri = importer && importer.public_url(file, sourcemap_dir)
          next unless source_uri
        end

        current_source_id = source_uri_to_id[source_uri]
        unless current_source_id
          current_source_id = next_source_id
          next_source_id += 1

          source_uri_to_id[source_uri] = current_source_id
          id_to_source_uri[current_source_id] = source_uri

          if options[:type] == :inline
            id_to_contents[current_source_id] =
              #nodyna <instance_variable_get-2972> <not yet classified>
              importer.find(file, {}).instance_variable_get('@template')
          end
        end

        [
          [m.input.start_pos, m.output.start_pos],
          [m.input.end_pos, m.output.end_pos]
        ].each do |source_pos, target_pos|
          if previous_target_line != target_pos.line
            line_data.push(segment_data_for_line.join(",")) unless segment_data_for_line.empty?
            (target_pos.line - 1 - (previous_target_line || 0)).times {line_data.push("")}
            previous_target_line = target_pos.line
            previous_target_offset = 1
            segment_data_for_line = []
          end

          segment = ""

          segment << Sass::Util.encode_vlq(target_pos.offset - previous_target_offset)
          previous_target_offset = target_pos.offset

          segment << Sass::Util.encode_vlq(current_source_id - previous_source_id)
          previous_source_id = current_source_id

          segment << Sass::Util.encode_vlq(source_pos.line - previous_source_line)
          previous_source_line = source_pos.line

          segment << Sass::Util.encode_vlq(source_pos.offset - previous_source_offset)
          previous_source_offset = source_pos.offset

          segment_data_for_line.push(segment)

          previous_target_line = target_pos.line
        end
      end
      line_data.push(segment_data_for_line.join(","))
      write_json_field(result, "mappings", line_data.join(";"))

      source_names = []
      (0...next_source_id).each {|id| source_names.push(id_to_source_uri[id].to_s)}
      write_json_field(result, "sources", source_names)

      if options[:type] == :inline
        write_json_field(result, "sourcesContent",
          (0...next_source_id).map {|id| id_to_contents[id]})
      end

      write_json_field(result, "names", [])
      write_json_field(result, "file", css_uri)

      result << "\n}"
      result
    end

    private

    def write_json_field(out, name, value, is_first = false)
      out << (is_first ? "" : ",\n") <<
        "\"" <<
        Sass::Util.json_escape_string(name) <<
        "\": " <<
        Sass::Util.json_value_of(value)
    end
  end
end
