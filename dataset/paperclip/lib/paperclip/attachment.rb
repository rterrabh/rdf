require 'uri'
require 'paperclip/url_generator'
require 'active_support/deprecation'

module Paperclip
  class Attachment
    def self.default_options
      @default_options ||= {
        :convert_options       => {},
        :default_style         => :original,
        :default_url           => "/:attachment/:style/missing.png",
        :escape_url            => true,
        :restricted_characters => /[&$+,\/:;=?@<>\[\]\{\}\|\\\^~%# ]/,
        :filename_cleaner      => nil,
        :hash_data             => ":class/:attachment/:id/:style/:updated_at",
        :hash_digest           => "SHA1",
        :interpolator          => Paperclip::Interpolations,
        :only_process          => [],
        :path                  => ":rails_root/public:url",
        :preserve_files        => false,
        :processors            => [:thumbnail],
        :source_file_options   => {},
        :storage               => :filesystem,
        :styles                => {},
        :url                   => "/system/:class/:attachment/:id_partition/:style/:filename",
        :url_generator         => Paperclip::UrlGenerator,
        :use_default_time_zone => true,
        :use_timestamp         => true,
        :whiny                 => Paperclip.options[:whiny] || Paperclip.options[:whiny_thumbnails],
        :validate_media_type   => true,
        :check_validity_before_processing => true
      }
    end

    attr_reader :name, :instance, :default_style, :convert_options, :queued_for_write, :whiny,
                :options, :interpolator, :source_file_options
    attr_accessor :post_processing

    def initialize(name, instance, options = {})
      @name              = name
      @instance          = instance

      options = self.class.default_options.deep_merge(options)

      @options               = options
      @post_processing       = true
      @queued_for_delete     = []
      @queued_for_write      = {}
      @errors                = {}
      @dirty                 = false
      @interpolator          = options[:interpolator]
      @url_generator         = options[:url_generator].new(self, @options)
      @source_file_options   = options[:source_file_options]
      @whiny                 = options[:whiny]

      initialize_storage
    end

    def assign(uploaded_file)
      @file = Paperclip.io_adapters.for(uploaded_file)
      ensure_required_accessors!
      ensure_required_validations!

      if @file.assignment?
        clear(*only_process)

        if @file.nil?
          nil
        else
          assign_attributes
          post_process_file
          reset_file_if_original_reprocessed
        end
      else
        nil
      end
    end


    def url(style_name = default_style, options = {})
      return nil if @instance.new_record?

      if options == true || options == false # Backwards compatibility.
        @url_generator.for(style_name, default_options.merge(:timestamp => options))
      else
        @url_generator.for(style_name, default_options.merge(options))
      end
    end

    def default_options
      {
        :timestamp => @options[:use_timestamp],
        :escape => @options[:escape_url]
      }
    end

    def expiring_url(time = 3600, style_name = default_style)
      url(style_name)
    end

    def path(style_name = default_style)
      path = original_filename.nil? ? nil : interpolate(path_option, style_name)
      path.respond_to?(:unescape) ? path.unescape : path
    end

    def staged_path(style_name = default_style)
      if staged?
        @queued_for_write[style_name].path
      end
    end

    def staged?
      ! @queued_for_write.empty?
    end

    def to_s style_name = default_style
      url(style_name)
    end

    def as_json(options = nil)
      to_s((options && options[:style]) || default_style)
    end

    def default_style
      @options[:default_style]
    end

    def styles
      if @options[:styles].respond_to?(:call) || @normalized_styles.nil?
        styles = @options[:styles]
        styles = styles.call(self) if styles.respond_to?(:call)

        @normalized_styles = styles.dup
        styles.each_pair do |name, options|
          @normalized_styles[name.to_sym] = Paperclip::Style.new(name.to_sym, options.dup, self)
        end
      end
      @normalized_styles
    end

    def only_process
      only_process = @options[:only_process].dup
      only_process = only_process.call(self) if only_process.respond_to?(:call)
      only_process.map(&:to_sym)
    end

    def processors
      processing_option = @options[:processors]

      if processing_option.respond_to?(:call)
        processing_option.call(instance)
      else
        processing_option
      end
    end

    def errors
      @errors
    end

    def dirty?
      @dirty
    end

    def save
      flush_deletes unless @options[:keep_old_files]
      flush_writes
      @dirty = false
      true
    end

    def clear(*styles_to_clear)
      if styles_to_clear.any?
        queue_some_for_delete(*styles_to_clear)
      else
        queue_all_for_delete
        @queued_for_write  = {}
        @errors            = {}
      end
    end

    def destroy
      clear
      save
    end

    def uploaded_file
      instance_read(:uploaded_file)
    end

    def original_filename
      instance_read(:file_name)
    end

    def size
      instance_read(:file_size) || (@queued_for_write[:original] && @queued_for_write[:original].size)
    end

    def fingerprint
      instance_read(:fingerprint)
    end

    def content_type
      instance_read(:content_type)
    end

    def created_at
      if able_to_store_created_at?
        time = instance_read(:created_at)
        time && time.to_f.to_i
      end
    end

    def updated_at
      time = instance_read(:updated_at)
      time && time.to_f.to_i
    end

    def time_zone
      @options[:use_default_time_zone] ? Time.zone_default : Time.zone
    end

    def hash_key(style_name = default_style)
      raise ArgumentError, "Unable to generate hash without :hash_secret" unless @options[:hash_secret]
      require 'openssl' unless defined?(OpenSSL)
      data = interpolate(@options[:hash_data], style_name)
      #nodyna <const_get-710> <CG COMPLEX (change-prone variable)>
      OpenSSL::HMAC.hexdigest(OpenSSL::Digest.const_get(@options[:hash_digest]).new, @options[:hash_secret], data)
    end

    def reprocess!(*style_args)
      saved_only_process, @options[:only_process] = @options[:only_process], style_args
      saved_preserve_files, @options[:preserve_files] = @options[:preserve_files], true
      begin
        assign(self)
        save
        instance.save
      rescue Errno::EACCES => e
        warn "#{e} - skipping file."
        false
      ensure
        @options[:only_process] = saved_only_process
        @options[:preserve_files] = saved_preserve_files
      end
    end

    def file?
      !original_filename.blank?
    end

    alias :present? :file?

    def blank?
      not present?
    end

    def instance_respond_to?(attr)
      instance.respond_to?(:"#{name}_#{attr}")
    end

    def instance_write(attr, value)
      setter = :"#{name}_#{attr}="
      if instance.respond_to?(setter)
        #nodyna <send-711> <SD COMPLEX (change-prone variables)>
        instance.send(setter, value)
      end
    end

    def instance_read(attr)
      getter = :"#{name}_#{attr}"
      if instance.respond_to?(getter)
        #nodyna <send-712> <SD COMPLEX (change-prone variables)>
        instance.send(getter)
      end
    end

    private

    def path_option
      @options[:path].respond_to?(:call) ? @options[:path].call(self) : @options[:path]
    end

    def active_validator_classes
      @instance.class.validators.map(&:class)
    end

    def missing_required_validator?
      (active_validator_classes.flat_map(&:ancestors) & Paperclip::REQUIRED_VALIDATORS).empty?
    end

    def ensure_required_validations!
      if missing_required_validator?
        raise Paperclip::Errors::MissingRequiredValidatorError
      end
    end

    def ensure_required_accessors! #:nodoc:
      %w(file_name).each do |field|
        unless @instance.respond_to?("#{name}_#{field}") && @instance.respond_to?("#{name}_#{field}=")
          raise Paperclip::Error.new("#{@instance.class} model missing required attr_accessor for '#{name}_#{field}'")
        end
      end
    end

    def log message #:nodoc:
      Paperclip.log(message)
    end

    def initialize_storage #:nodoc:
      storage_class_name = @options[:storage].to_s.downcase.camelize
      begin
        #nodyna <const_get-713> <CG COMPLEX (change-prone variable)>
        storage_module = Paperclip::Storage.const_get(storage_class_name)
      rescue NameError
        raise Errors::StorageMethodNotFound, "Cannot load storage module '#{storage_class_name}'"
      end
      self.extend(storage_module)
    end

    def assign_attributes
      @queued_for_write[:original] = @file
      assign_file_information
      assign_fingerprint(@file.fingerprint)
      assign_timestamps
    end

    def assign_file_information
      instance_write(:file_name, cleanup_filename(@file.original_filename))
      instance_write(:content_type, @file.content_type.to_s.strip)
      instance_write(:file_size, @file.size)
    end

    def assign_fingerprint(fingerprint)
      if instance_respond_to?(:fingerprint)
        instance_write(:fingerprint, fingerprint)
      end
    end

    def assign_timestamps
      if has_enabled_but_unset_created_at?
        instance_write(:created_at, Time.now)
      end

      instance_write(:updated_at, Time.now)
    end

    def post_process_file
      dirty!

      if post_processing
        post_process(*only_process)
      end
    end

    def dirty!
      @dirty = true
    end

    def reset_file_if_original_reprocessed
      instance_write(:file_size, @queued_for_write[:original].size)
      assign_fingerprint(@queued_for_write[:original].fingerprint)
      reset_updater
    end

    def reset_updater
      if instance.respond_to?(updater)
        #nodyna <send-714> <SD COMPLEX (change-prone variables)>
        instance.send(updater)
      end
    end

    def updater
      :"#{name}_file_name_will_change!"
    end

    def extra_options_for(style) #:nodoc:
      process_options(:convert_options, style)
    end

    def extra_source_file_options_for(style) #:nodoc:
      process_options(:source_file_options, style)
    end

    def process_options(options_type, style) #:nodoc:
      all_options   = @options[options_type][:all]
      all_options   = all_options.call(instance)   if all_options.respond_to?(:call)
      style_options = @options[options_type][style]
      style_options = style_options.call(instance) if style_options.respond_to?(:call)

      [ style_options, all_options ].compact.join(" ")
    end

    def post_process(*style_args) #:nodoc:
      return if @queued_for_write[:original].nil?

      instance.run_paperclip_callbacks(:post_process) do
        instance.run_paperclip_callbacks(:"#{name}_post_process") do
          unless @options[:check_validity_before_processing] && instance.errors.any?
            post_process_styles(*style_args)
          end
        end
      end
    end

    def post_process_styles(*style_args) #:nodoc:
      post_process_style(:original, styles[:original]) if styles.include?(:original) && process_style?(:original, style_args)
      styles.reject{ |name, style| name == :original }.each do |name, style|
        post_process_style(name, style) if process_style?(name, style_args)
      end
    end

    def post_process_style(name, style) #:nodoc:
      begin
        raise RuntimeError.new("Style #{name} has no processors defined.") if style.processors.blank?
        intermediate_files = []

        @queued_for_write[name] = style.processors.inject(@queued_for_write[:original]) do |file, processor|
          file = Paperclip.processor(processor).make(file, style.processor_options, self)
          intermediate_files << file
          file
        end

        unadapted_file = @queued_for_write[name]
        @queued_for_write[name] = Paperclip.io_adapters.for(@queued_for_write[name])
        unadapted_file.close if unadapted_file.respond_to?(:close)
        @queued_for_write[name]
      rescue Paperclip::Errors::NotIdentifiedByImageMagickError => e
        log("An error was received while processing: #{e.inspect}")
        (@errors[:processing] ||= []) << e.message if @options[:whiny]
      ensure
        unlink_files(intermediate_files)
      end
    end

    def process_style?(style_name, style_args) #:nodoc:
      style_args.empty? || style_args.include?(style_name)
    end

    def interpolate(pattern, style_name = default_style) #:nodoc:
      interpolator.interpolate(pattern, self, style_name)
    end

    def queue_some_for_delete(*styles)
      @queued_for_delete += styles.uniq.map do |style|
        path(style) if exists?(style)
      end.compact
    end

    def queue_all_for_delete #:nodoc:
      return if !file?
      unless @options[:preserve_files]
        @queued_for_delete += [:original, *styles.keys].uniq.map do |style|
          path(style) if exists?(style)
        end.compact
      end
      instance_write(:file_name, nil)
      instance_write(:content_type, nil)
      instance_write(:file_size, nil)
      instance_write(:fingerprint, nil)
      instance_write(:created_at, nil) if has_enabled_but_unset_created_at?
      instance_write(:updated_at, nil)
    end

    def flush_errors #:nodoc:
      @errors.each do |error, message|
        [message].flatten.each {|m| instance.errors.add(name, m) }
      end
    end

    def after_flush_writes
      unlink_files(@queued_for_write.values)
    end

    def unlink_files(files)
      Array(files).each do |file|
        file.close unless file.closed?
        file.unlink if file.respond_to?(:unlink) && file.path.present? && File.exist?(file.path)
      end
    end

    def filename_cleaner
      @options[:filename_cleaner] || FilenameCleaner.new(@options[:restricted_characters])
    end

    def cleanup_filename(filename)
      filename_cleaner.call(filename)
    end

    def able_to_store_created_at?
      @instance.respond_to?("#{name}_created_at".to_sym)
    end

    def has_enabled_but_unset_created_at?
      able_to_store_created_at? && !instance_read(:created_at)
    end
  end
end
