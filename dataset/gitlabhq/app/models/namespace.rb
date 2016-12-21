# == Schema Information
#
# Table name: namespaces
#
#  id          :integer          not null, primary key
#  name        :string(255)      not null
#  path        :string(255)      not null
#  owner_id    :integer
#  created_at  :datetime
#  updated_at  :datetime
#  type        :string(255)
#  description :string(255)      default(""), not null
#  avatar      :string(255)
#

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

    # Case insensetive search for namespace by path or name
    def find_by_path_or_name(path)
      find_by("lower(path) = :path OR lower(name) = :path", path: path.downcase)
    end

    def search(query)
      where("name LIKE :query OR path LIKE :query", query: "%#{query}%")
    end

    def clean_path(path)
      path = path.dup
      # Get the email username by removing everything after an `@` sign.
      path.gsub!(/@.*\z/,             "")
      # Usernames can't end in .git, so remove it.
      path.gsub!(/\.git\z/,           "")
      # Remove dashes at the start of the username.
      path.gsub!(/\A-+/,              "")
      # Remove periods at the end of the username.
      path.gsub!(/\.+\z/,             "")
      # Remove everything that's not in the list of allowed characters.
      path.gsub!(/[^a-zA-Z0-9_\-\.]/, "")

      # Users with the great usernames of "." or ".." would end up with a blank username.
      # Work around that by setting their username to "blank", followed by a counter.
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
    # Move namespace directory into trash.
    # We will remove it later async
    new_path = "#{path}+#{id}+deleted"

    if gitlab_shell.mv_namespace(path, new_path)
      message = "Namespace directory \"#{path}\" moved to \"#{new_path}\""
      Gitlab::AppLogger.info message

      # Remove namespace directroy async with delay so
      # GitLab has time to remove all projects first
      GitlabShellWorker.perform_in(5.minutes, :rm_namespace, new_path)
    end
  end

  def move_dir
    # Ensure old directory exists before moving it
    gitlab_shell.add_namespace(path_was)

    if gitlab_shell.mv_namespace(path_was, path)
      # If repositories moved successfully we need to remove old satellites
      # and send update instructions to users.
      # However we cannot allow rollback since we moved namespace dir
      # So we basically we mute exceptions in next actions
      begin
        gitlab_shell.rm_satellites(path_was)
        send_update_instructions
      rescue
        # Returning false does not rollback after_* transaction but gives
        # us information about failing some of tasks
        false
      end
    else
      # if we cannot move namespace directory we should rollback
      # db changes in order to prevent out of sync between db and fs
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
