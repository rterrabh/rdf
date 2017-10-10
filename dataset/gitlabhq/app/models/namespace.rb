
class Namespace < ActiveRecord::Base
  include Sortable
  include Gitlab::ShellAdapter

  has_many :projects, dependent: :destroy
  belongs_to :owner, class_name: "User"

  validates :owner, presence: true, unless: ->(n) { n.type == "Group" }
  validates :name,
    presence: true, uniqueness: true,
    length: { within: 0..255 },
    format: { with: Gitlab::Regex.namespace_name_regex,
              message: Gitlab::Regex.namespace_name_regex_message }

  validates :description, length: { within: 0..255 }
  validates :path,
    uniqueness: { case_sensitive: false },
    presence: true,
    length: { within: 1..255 },
    exclusion: { in: Gitlab::Blacklist.path },
    format: { with: Gitlab::Regex.namespace_regex,
              message: Gitlab::Regex.namespace_regex_message }

  delegate :name, to: :owner, allow_nil: true, prefix: true

  after_create :ensure_dir_exist
  after_update :move_dir, if: :path_changed?
  after_destroy :rm_dir

  scope :root, -> { where('type IS NULL') }

  class << self
    def by_path(path)
      where('lower(path) = :value', value: path.downcase).first
    end

    def find_by_path_or_name(path)
      find_by("lower(path) = :path OR lower(name) = :path", path: path.downcase)
    end

    def search(query)
      where("name LIKE :query OR path LIKE :query", query: "%#{query}%")
    end

    def clean_path(path)
      path = path.dup
      path.gsub!(/@.*\z/,             "")
      path.gsub!(/\.git\z/,           "")
      path.gsub!(/\A-+/,              "")
      path.gsub!(/\.+\z/,             "")
      path.gsub!(/[^a-zA-Z0-9_\-\.]/, "")

      path = "blank" if path.blank?

      counter = 0
      base = path
      while Namespace.find_by_path_or_name(path)
        counter += 1
        path = "#{base}#{counter}"
      end

      path
    end
  end

  def to_param
    path
  end

  def human_name
    owner_name
  end

  def ensure_dir_exist
    gitlab_shell.add_namespace(path)
  end

  def rm_dir
    new_path = "#{path}+#{id}+deleted"

    if gitlab_shell.mv_namespace(path, new_path)
      message = "Namespace directory \"#{path}\" moved to \"#{new_path}\""
      Gitlab::AppLogger.info message

      GitlabShellWorker.perform_in(5.minutes, :rm_namespace, new_path)
    end
  end

  def move_dir
    gitlab_shell.add_namespace(path_was)

    if gitlab_shell.mv_namespace(path_was, path)
      begin
        gitlab_shell.rm_satellites(path_was)
        send_update_instructions
      rescue
        false
      end
    else
      raise Exception.new('namespace directory cannot be moved')
    end
  end

  def send_update_instructions
    projects.each(&:send_move_instructions)
  end

  def kind
    type == 'Group' ? 'group' : 'user'
  end

  def find_fork_of(project)
    projects.joins(:forked_project_link).where('forked_project_links.forked_from_project_id = ?', project.id).first
  end
end
