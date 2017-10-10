require 'fileutils'

require 'sass'
require 'sass/callbacks'
require 'sass/plugin/configuration'
require 'sass/plugin/staleness_checker'

module Sass::Plugin
  class Compiler
    include Configuration
    extend Sass::Callbacks

    def initialize(opts = {})
      @watched_files = Set.new
      options.merge!(opts)
    end

    define_callback :updating_stylesheets

    define_callback :updated_stylesheets

    define_callback :updated_stylesheet

    define_callback :compilation_starting

    define_callback :not_updating_stylesheet

    define_callback :compilation_error

    define_callback :creating_directory

    define_callback :template_modified

    define_callback :template_created

    define_callback :template_deleted

    define_callback :deleting_css

    define_callback :deleting_sourcemap

    def update_stylesheets(individual_files = [])
      Sass::Plugin.checked_for_updates = true
      staleness_checker = StalenessChecker.new(engine_options)

      files = file_list(individual_files)
      run_updating_stylesheets(files)

      updated_stylesheets = []
      files.each do |file, css, sourcemap|
        if options[:always_update] || staleness_checker.stylesheet_needs_update?(css, file)
          updated_stylesheets << [file, css]
          update_stylesheet(file, css, sourcemap)
        else
          run_not_updating_stylesheet(file, css, sourcemap)
        end
      end
      run_updated_stylesheets(updated_stylesheets)
    end

    def file_list(individual_files = [])
      files = individual_files.map do |tuple|
        if engine_options[:sourcemap] == :none
          tuple[0..1]
        elsif tuple.size < 3
          [tuple[0], tuple[1], Sass::Util.sourcemap_name(tuple[1])]
        else
          tuple.dup
        end
      end

      template_location_array.each do |template_location, css_location|
        Sass::Util.glob(File.join(template_location, "**", "[^_]*.s[ca]ss")).sort.each do |file|
          name = Sass::Util.relative_path_from(file, template_location).to_s
          css = css_filename(name, css_location)
          sourcemap = Sass::Util.sourcemap_name(css) unless engine_options[:sourcemap] == :none
          files << [file, css, sourcemap]
        end
      end
      files
    end

    def watch(individual_files = [], options = {})
      options, individual_files = individual_files, [] if individual_files.is_a?(Hash)
      update_stylesheets(individual_files) unless options[:skip_initial_update]

      directories = watched_paths
      individual_files.each do |(source, _, _)|
        source = File.expand_path(source)
        @watched_files << Sass::Util.realpath(source).to_s
        directories << File.dirname(source)
      end
      directories = remove_redundant_directories(directories)

      unless Sass::Util.listen_geq_2?
        directories = directories.select {|d| File.directory?(d) && File.writable?(d)}
      end

      listener_args = directories +
                      Array(options[:additional_watch_paths]) +
                      [{:relative_paths => false}]

      poll = @options[:poll] || Sass::Util.windows?
      if poll && Sass::Util.listen_geq_2?
        listener_args.last[:force_polling] = true
      end

      listener = create_listener(*listener_args) do |modified, added, removed|
        on_file_changed(individual_files, modified, added, removed)
        yield(modified, added, removed) if block_given?
      end

      if poll && !Sass::Util.listen_geq_2?
        listener.force_polling(true)
      end

      listen_to(listener)
    end

    def engine_options(additional_options = {})
      opts = options.merge(additional_options)
      opts[:load_paths] = load_paths(opts)
      options[:sourcemap] = :auto if options[:sourcemap] == true
      options[:sourcemap] = :none if options[:sourcemap] == false
      opts
    end

    def stylesheet_needs_update?(css_file, template_file)
      StalenessChecker.stylesheet_needs_update?(css_file, template_file)
    end

    def clean(individual_files = [])
      file_list(individual_files).each do |(_, css_file, sourcemap_file)|
        if File.exist?(css_file)
          run_deleting_css css_file
          File.delete(css_file)
        end
        if sourcemap_file && File.exist?(sourcemap_file)
          run_deleting_sourcemap sourcemap_file
          File.delete(sourcemap_file)
        end
      end
      nil
    end

    private

    def create_listener(*args, &block)
      Sass::Util.load_listen!
      if Sass::Util.listen_geq_2?
        options = args.pop if args.last.is_a?(Hash)
        args.map do |dir|
          Listen.to(dir, options, &block)
        end
      else
        Listen::Listener.new(*args, &block)
      end
    end

    def listen_to(listener)
      if Sass::Util.listen_geq_2?
        listener.map {|l| l.start}
        sleep
      else
        listener.start!
      end
    rescue Interrupt
    end

    def remove_redundant_directories(directories)
      dedupped = []
      directories.each do |new_directory|
        next if dedupped.any? do |existing_directory|
          child_of_directory?(existing_directory, new_directory)
        end
        dedupped.reject! do |existing_directory|
          child_of_directory?(new_directory, existing_directory)
        end
        dedupped << new_directory
      end
      dedupped
    end

    def on_file_changed(individual_files, modified, added, removed)
      recompile_required = false

      modified.uniq.each do |f|
        next unless watched_file?(f)
        recompile_required = true
        run_template_modified(relative_to_pwd(f))
      end

      added.uniq.each do |f|
        next unless watched_file?(f)
        recompile_required = true
        run_template_created(relative_to_pwd(f))
      end

      removed.uniq.each do |f|
        next unless watched_file?(f)
        run_template_deleted(relative_to_pwd(f))
        if (files = individual_files.find {|(source, _, _)| File.expand_path(source) == f})
          recompile_required = true
          try_delete_css files[1]
        else
          next unless watched_file?(f)
          recompile_required = true
          template_location_array.each do |(sass_dir, css_dir)|
            sass_dir = File.expand_path(sass_dir)
            if child_of_directory?(sass_dir, f)
              remainder = f[(sass_dir.size + 1)..-1]
              try_delete_css(css_filename(remainder, css_dir))
              break
            end
          end
        end
      end

      if recompile_required
        watched_files_remaining = individual_files.select {|(source, _, _)| File.exist?(source)}
        update_stylesheets(watched_files_remaining)
      end
    end

    def update_stylesheet(filename, css, sourcemap)
      dir = File.dirname(css)
      unless File.exist?(dir)
        run_creating_directory dir
        FileUtils.mkdir_p dir
      end

      begin
        File.read(filename) unless File.readable?(filename) # triggers an error for handling
        engine_opts = engine_options(:css_filename => css,
                                     :filename => filename,
                                     :sourcemap_filename => sourcemap)
        mapping = nil
        run_compilation_starting(filename, css, sourcemap)
        engine = Sass::Engine.for_file(filename, engine_opts)
        if sourcemap
          rendered, mapping = engine.render_with_sourcemap(File.basename(sourcemap))
        else
          rendered = engine.render
        end
      rescue StandardError => e
        compilation_error_occured = true
        run_compilation_error e, filename, css, sourcemap
        raise e unless options[:full_exception]
        rendered = Sass::SyntaxError.exception_to_css(e, options[:line] || 1)
      end

      write_file(css, rendered)
      if mapping
        write_file(sourcemap, mapping.to_json(
            :css_path => css, :sourcemap_path => sourcemap, :type => options[:sourcemap]))
      end
      run_updated_stylesheet(filename, css, sourcemap) unless compilation_error_occured
    end

    def write_file(fileName, content)
      flag = 'w'
      flag = 'wb' if Sass::Util.windows? && options[:unix_newlines]
      File.open(fileName, flag) do |file|
        file.set_encoding(content.encoding) unless Sass::Util.ruby1_8?
        file.print(content)
      end
    end

    def try_delete_css(css)
      if File.exist?(css)
        run_deleting_css css
        File.delete css
      end
      map = Sass::Util.sourcemap_name(css)
      if File.exist?(map)
        run_deleting_sourcemap map
        File.delete map
      end
    end

    def watched_file?(file)
      @watched_files.include?(file) || normalized_load_paths.any? {|lp| lp.watched_file?(file)}
    end

    def watched_paths
      @watched_paths ||= normalized_load_paths.map {|lp| lp.directories_to_watch}.compact.flatten
    end

    def normalized_load_paths
      @normalized_load_paths ||=
        Sass::Engine.normalize_options(:load_paths => load_paths)[:load_paths]
    end

    def load_paths(opts = options)
      (opts[:load_paths] || []) + template_locations
    end

    def template_locations
      template_location_array.to_a.map {|l| l.first}
    end

    def css_locations
      template_location_array.to_a.map {|l| l.last}
    end

    def css_filename(name, path)
      "#{path}#{File::SEPARATOR unless path.end_with?(File::SEPARATOR)}#{name}".
        gsub(/\.s[ac]ss$/, '.css')
    end

    def relative_to_pwd(f)
      Sass::Util.relative_path_from(f, Dir.pwd).to_s
    rescue ArgumentError # when a relative path cannot be computed
      f
    end

    def child_of_directory?(parent, child)
      parent_dir = parent.end_with?(File::SEPARATOR) ? parent : (parent + File::SEPARATOR)
      child.start_with?(parent_dir) || parent == child
    end
  end
end
