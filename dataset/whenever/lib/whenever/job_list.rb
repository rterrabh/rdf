module Whenever
  class JobList
    attr_reader :roles

    def initialize(options)
      @jobs, @env, @set_variables, @pre_set_variables = {}, {}, {}, {}

      if options.is_a? String
        options = { :string => options }
      end

      pre_set(options[:set])

      @roles = options[:roles] || []

      setup_file = File.expand_path('../setup.rb', __FILE__)
      setup = File.read(setup_file)
      schedule = if options[:string]
        options[:string]
      elsif options[:file]
        File.read(options[:file])
      end

      #nodyna <instance_eval-3091> <IEV COMPLEX (block execution)>
      instance_eval(Whenever::NumericSeconds.process_string(setup), setup_file)
      #nodyna <instance_eval-3093> <IEV COMPLEX (block execution)>
      instance_eval(Whenever::NumericSeconds.process_string(schedule), options[:file] || '<eval>')
    end

    def set(variable, value)
      variable = variable.to_sym
      return if @pre_set_variables[variable]

      #nodyna <instance_variable_set-3094> <IVS MODERATE (change-prone variables)>
      instance_variable_set("@#{variable}".to_sym, value)
      #nodyna <send-3095> <SD MODERATE (private functions)>
      self.class.send(:attr_reader, variable.to_sym)
      @set_variables[variable] = value
    end

    def env(variable, value)
      @env[variable.to_s] = value
    end

    def every(frequency, options = {})
      @current_time_scope = frequency
      @options = options
      yield
    end

    def job_type(name, template)
      #nodyna <class_eval-3096> <CE MODERATE (method definition)>
      singleton_class_shim.class_eval do
        #nodyna <define_method-3097> <DM MODERATE (events)>
        define_method(name) do |task, *args|
          options = { :task => task, :template => template }
          options.merge!(args[0]) if args[0].is_a? Hash

          options[:output] = (options[:cron_log] || @cron_log) if defined?(@cron_log) || options.has_key?(:cron_log)
          options[:output] = @output if defined?(@output) && !options.has_key?(:output)

          @jobs[@current_time_scope] ||= []
          @jobs[@current_time_scope] << Whenever::Job.new(@options.merge(@set_variables).merge(options))
        end
      end
    end

    def generate_cron_output
      [environment_variables, cron_jobs].compact.join
    end

  private

    def singleton_class_shim
      if self.respond_to?(:singleton_class)
        singleton_class
      else
        class << self; self; end
      end
    end

    def pre_set(variable_string = nil)
      return if variable_string.nil? || variable_string == ""

      pairs = variable_string.split('&')
      pairs.each do |pair|
        next unless pair.index('=')
        variable, value = *pair.split('=')
        unless variable.nil? || variable == "" || value.nil? || value == ""
          variable = variable.strip.to_sym
          set(variable, value.strip)
          @pre_set_variables[variable] = value
        end
      end
    end

    def environment_variables
      return if @env.empty?

      output = []
      @env.each do |key, val|
        output << "#{key}=#{val.nil? || val == "" ? '""' : val}\n"
      end
      output << "\n"

      output.join
    end

    def combine(entries)
      entries.map! { |entry| entry.split(/ +/, 6) }
      0.upto(4) do |f|
        (entries.length-1).downto(1) do |i|
          next if entries[i][f] == '*'
          comparison = entries[i][0...f] + entries[i][f+1..-1]
          (i-1).downto(0) do |j|
            next if entries[j][f] == '*'
            if comparison == entries[j][0...f] + entries[j][f+1..-1]
              entries[j][f] += ',' + entries[i][f]
              entries.delete_at(i)
              break
            end
          end
        end
      end

      entries.map { |entry| entry.join(' ') }
    end

    def cron_jobs
      return if @jobs.empty?

      shortcut_jobs = []
      regular_jobs = []

      output_all = roles.empty?
      @jobs.each do |time, jobs|
        jobs.each do |job|
          next unless output_all || roles.any? do |r|
            job.has_role?(r)
          end
          Whenever::Output::Cron.output(time, job) do |cron|
            cron << "\n\n"

            if cron[0,1] == "@"
              shortcut_jobs << cron
            else
              regular_jobs << cron
            end
          end
        end
      end

      shortcut_jobs.join + combine(regular_jobs).join
    end
  end
end