module Hbc::Scopes
  def self.included(base)
    base.extend(ClassMethods)
  end

  module ClassMethods
    def all
      all_tokens.map { |c| self.load c }
    end

    def all_tapped_cask_dirs
      return @all_tapped_cask_dirs unless @all_tapped_cask_dirs.nil?
      fq_default_tap = Hbc.homebrew_tapspath.join(default_tap, 'Casks')
      @all_tapped_cask_dirs = Dir.glob(Hbc.homebrew_tapspath.join('*', '*', 'Casks')).map { |d| Pathname.new(d) }
      if @all_tapped_cask_dirs.include? fq_default_tap
        @all_tapped_cask_dirs = @all_tapped_cask_dirs - [ fq_default_tap ]
        @all_tapped_cask_dirs.unshift fq_default_tap
      end
      @all_tapped_cask_dirs
    end

    def reset_all_tapped_cask_dirs
      @all_tapped_cask_dirs = nil
    end

    def all_tokens
      cask_tokens = all_tapped_cask_dirs.map { |d| Dir.glob d.join('*.rb') }.flatten
      cask_tokens.map { |c|
        c.sub!(/\.rb$/, '')
        c = c.split('/').last 4
        c.delete_at(-2)
        c = c.join '/'
      }
    end

    def installed
      installed_cask_dirs = Pathname.glob(caskroom.join("*"))
      installed_cask_dirs.map do |install_dir|
        cask_token = install_dir.basename.to_s
        path_to_cask = all_tapped_cask_dirs.find do |tap_dir|
          tap_dir.join("#{cask_token}.rb").exist?
        end
        if path_to_cask
          Hbc.load(path_to_cask.join("#{cask_token}.rb"))
        else
          Hbc.load(cask_token)
        end
      end
    end
  end
end
