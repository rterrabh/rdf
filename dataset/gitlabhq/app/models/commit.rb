class Commit
  extend ActiveModel::Naming

  include ActiveModel::Conversion
  include Mentionable
  include Participable
  include Referable
  include StaticModel

  attr_mentionable :safe_message
  participant :author, :committer, :notes, :mentioned_users

  attr_accessor :project

  DIFF_SAFE_FILES  = 100 unless defined?(DIFF_SAFE_FILES)
  DIFF_SAFE_LINES  = 5000 unless defined?(DIFF_SAFE_LINES)

  DIFF_HARD_LIMIT_FILES = 1000 unless defined?(DIFF_HARD_LIMIT_FILES)
  DIFF_HARD_LIMIT_LINES = 50000 unless defined?(DIFF_HARD_LIMIT_LINES)

  class << self
    def decorate(commits, project)
      commits.map do |commit|
        if commit.kind_of?(Commit)
          commit
        else
          self.new(commit, project)
        end
      end
    end

    def diff_line_count(diffs)
      diffs.reduce(0) { |sum, d| sum + d.diff.lines.count }
    end

    def truncate_sha(sha)
      sha[0..7]
    end
  end

  attr_accessor :raw

  def initialize(raw_commit, project)
    raise "Nil as raw commit passed" unless raw_commit

    @raw = raw_commit
    @project = project
  end

  def id
    @raw.id
  end

  def ==(other)
    (self.class === other) && (raw == other.raw)
  end

  def self.reference_prefix
    '@'
  end

  def self.reference_pattern
    %r{
      (?:#{Project.reference_pattern}#{reference_prefix})?
      (?<commit>\h{6,40})
    }x
  end

  def to_reference(from_project = nil)
    if cross_project_reference?(from_project)
      "#{project.to_reference}@#{id}"
    else
      id
    end
  end

  def diff_line_count
    @diff_line_count ||= Commit::diff_line_count(self.diffs)
    @diff_line_count
  end

  def link_title
    "Commit: #{author_name} - #{title}"
  end

  def title
    title = safe_message

    return no_commit_message if title.blank?

    title_end = title.index("\n")
    if (!title_end && title.length > 100) || (title_end && title_end > 100)
      title[0..79] << "…"
    else
      title.split("\n", 2).first
    end
  end

  def description
    title_end = safe_message.index("\n")
    @description ||=
      if (!title_end && safe_message.length > 100) || (title_end && title_end > 100)
        "…" << safe_message[80..-1]
      else
        safe_message.split("\n", 2)[1].try(:chomp)
      end
  end

  def description?
    description.present?
  end

  def hook_attrs
    path_with_namespace = project.path_with_namespace

    {
      id: id,
      message: safe_message,
      timestamp: committed_date.xmlschema,
      url: "#{Gitlab.config.gitlab.url}/#{path_with_namespace}/commit/#{id}",
      author: {
        name: author_name,
        email: author_email
      }
    }
  end

  def closes_issues(current_user = self.committer)
    Gitlab::ClosingIssueExtractor.new(project, current_user).closed_by_message(safe_message)
  end

  def author
    @author ||= User.find_by_any_email(author_email)
  end

  def committer
    @committer ||= User.find_by_any_email(committer_email)
  end

  def notes
    project.notes.for_commit_id(self.id)
  end

  def method_missing(m, *args, &block)
    #nodyna <send-506> <SD COMPLEX (change-prone variables)>
    @raw.send(m, *args, &block)
  end

  def respond_to_missing?(method, include_private = false)
    @raw.respond_to?(method, include_private) || super
  end

  def short_id
    @raw.short_id(7)
  end

  def parents
    @parents ||= Commit.decorate(super, project)
  end
end
