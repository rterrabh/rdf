require "json"
require "pathname"
require "securerandom"
require "thread"

require "vagrant/util/silence_warnings"

module Vagrant
  class MachineIndex
    include Enumerable

    def initialize(data_dir)
      @data_dir   = data_dir
      @index_file = data_dir.join("index")
      @lock       = Monitor.new
      @machines  = {}
      @machine_locks = {}

      with_index_lock do
        unlocked_reload
      end
    end

    def delete(entry)
      return true if !entry.id

      @lock.synchronize do
        with_index_lock do
          return true if !@machines[entry.id]

          if !@machine_locks[entry.id]
            raise "Unlocked delete on machine: #{entry.id}"
          end

          unlocked_reload
          @machines.delete(entry.id)
          unlocked_save

          unlocked_release(entry.id)
        end
      end

      true
    end

    def each(reload=false)
      if reload
        @lock.synchronize do
          with_index_lock do
            unlocked_reload
          end
        end
      end

      @machines.each do |uuid, data|
        yield Entry.new(uuid, data.merge("id" => uuid))
      end
    end

    def get(uuid)
      entry = nil

      @lock.synchronize do
        with_index_lock do
          unlocked_reload

          data = find_by_prefix(uuid)
          return nil if !data
          uuid = data["id"]

          entry = Entry.new(uuid, data)

          lock_file = lock_machine(uuid)
          if !lock_file
            raise Errors::MachineLocked,
              name: entry.name,
              provider: entry.provider
          end

          @machine_locks[uuid] = lock_file
        end
      end

      entry
    end

    def include?(uuid)
      @lock.synchronize do
        with_index_lock do
          unlocked_reload
          return !!find_by_prefix(uuid)
        end
      end
    end

    def release(entry)
      @lock.synchronize do
        unlocked_release(entry.id)
      end
    end

    def set(entry)
      struct = entry.to_json_struct

      id     = entry.id

      @lock.synchronize do
        with_index_lock do
          unlocked_reload

          if !id
            self.each do |other|
              if entry.name == other.name &&
                entry.provider == other.provider &&
                entry.vagrantfile_path.to_s == other.vagrantfile_path.to_s
                id = other.id
                break
              end
            end

            id = SecureRandom.uuid.gsub("-", "") if !id

            lock_file = lock_machine(id)
            if !lock_file
              raise "Failed to lock new machine: #{entry.name}"
            end

            @machine_locks[id] = lock_file
          end

          if !@machine_locks[id]
            raise "Unlocked write on machine: #{id}"
          end

          @machines[id] = struct
          unlocked_save
        end
      end

      Entry.new(id, struct)
    end

    protected

    def find_by_prefix(prefix)
      @machines.each do |uuid, data|
        return data.merge("id" => uuid) if uuid.start_with?(prefix)
      end

      nil
    end

    def lock_machine(uuid)
      lock_path = @data_dir.join("#{uuid}.lock")
      lock_file = lock_path.open("w+")
      if lock_file.flock(File::LOCK_EX | File::LOCK_NB) === false
        lock_file.close
        lock_file = nil
      end

      lock_file
    end

    def unlocked_release(id)
      lock_file = @machine_locks[id]
      if lock_file
        lock_file.close
        begin
          File.delete(lock_file.path)
        rescue Errno::EACCES
        end

        @machine_locks.delete(id)
      end
    end

    def unlocked_reload
      return if !@index_file.file?

      data = nil
      begin
        data = JSON.load(@index_file.read)
      rescue JSON::ParserError
        raise Errors::CorruptMachineIndex, path: @index_file.to_s
      end

      if data
        if !data["version"] || data["version"].to_i != 1
          raise Errors::CorruptMachineIndex, path: @index_file.to_s
        end

        @machines = data["machines"] || {}
      end
    end

    def unlocked_save
      @index_file.open("w") do |f|
        f.write(JSON.dump({
          "version"  => 1,
          "machines" => @machines,
        }))
      end
    end


    def with_index_lock
      lock_path = "#{@index_file}.lock"
      File.open(lock_path, "w+") do |f|
        f.flock(File::LOCK_EX)
        yield
      end
    end

    class Entry
      attr_reader :id

      attr_accessor :local_data_path

      attr_accessor :name

      attr_accessor :provider

      attr_accessor :state

      attr_accessor :vagrantfile_name

      attr_accessor :vagrantfile_path

      attr_reader :updated_at

      attr_accessor :extra_data

      def initialize(id=nil, raw=nil)
        @extra_data = {}

        return if !raw

        @id               = id
        @local_data_path  = raw["local_data_path"]
        @name             = raw["name"]
        @provider         = raw["provider"]
        @state            = raw["state"]
        @vagrantfile_name = raw["vagrantfile_name"]
        @vagrantfile_path = raw["vagrantfile_path"]
        @updated_at       = raw["updated_at"]
        @extra_data       = raw["extra_data"] || {}

        @local_data_path = nil  if @local_data_path == ""
        @vagrantfile_path = nil if @vagrantfile_path == ""

        @local_data_path = Pathname.new(@local_data_path) if @local_data_path
        @vagrantfile_path = Pathname.new(@vagrantfile_path) if @vagrantfile_path
      end

      def valid?(home_path)
        return false if !vagrantfile_path
        return false if !vagrantfile_path.directory?

        found = false
        env = vagrant_env(home_path)
        env.active_machines.each do |name, provider|
          if name.to_s == self.name.to_s &&
            provider.to_s == self.provider.to_s
            found = true
            break
          end
        end

        return false if !found

        machine = nil
        begin
          machine = env.machine(self.name.to_sym, self.provider.to_sym)
        rescue Errors::MachineNotFound
          return false
        end

        return false if machine.state.id == MachineState::NOT_CREATED_ID

        true
      end

      def vagrant_env(home_path, **opts)
        Vagrant::Util::SilenceWarnings.silence! do
          Environment.new({
            cwd: @vagrantfile_path,
            home_path: home_path,
            local_data_path: @local_data_path,
            vagrantfile_name: @vagrantfile_name,
          }.merge(opts))
        end
      end

      def to_json_struct
        {
          "local_data_path"  => @local_data_path.to_s,
          "name"             => @name,
          "provider"         => @provider,
          "state"            => @state,
          "vagrantfile_name" => @vagrantfile_name,
          "vagrantfile_path" => @vagrantfile_path.to_s,
          "updated_at"       => @updated_at,
          "extra_data"       => @extra_data,
        }
      end
    end
  end
end
