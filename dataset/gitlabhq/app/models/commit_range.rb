class CommitRange
  include ActiveModel::Conversion
  include Referable

  attr_reader :sha_from, :notation, :sha_to

  attr_accessor :project

  attr_reader :exclude_start

  PATTERN = /\h{6,40}\.{2,3}\h{6,40}/

  def self.reference_prefix
    '@'
  end

  def self.reference_pattern
    %r{
      (?:#{Project.reference_pattern}#{reference_prefix})?
      (?<commit_range>#{PATTERN})
    }x
  end

  def initialize(range_string, project = nil)
    range_string.strip!

    unless range_string.match(/\A#{PATTERN}\z/)
      raise ArgumentError, "invalid CommitRange string format: #{range_string}"
    end

    @exclude_start = !range_string.include?('...')
    @sha_from, @notation, @sha_to = range_string.split(/(\.{2,3})/, 2)

    @project = project
  end

  def inspect
    %(#<#{self.class}:#{object_id} #{to_s}>)
  end

  def to_s
    "#{sha_from[0..7]}#{notation}#{sha_to[0..7]}"
  end

  def to_reference(from_project = nil)
    reference = sha_from + notation + sha_to

    if cross_project_reference?(from_project)
      reference = project.to_reference + '@' + reference
    end

    reference
  end

  def reference_title
    "Commits #{suffixed_sha_from} through #{sha_to}"
  end

  def to_param
    { from: suffixed_sha_from, to: sha_to }
  end

  def exclude_start?
    exclude_start
  end

  def valid_commits?(project = project)
    return nil   unless project.present?
    return false unless project.valid_repo?

    commit_from.present? && commit_to.present?
  end

  def persisted?
    true
  end

  def commit_from
    @commit_from ||= project.repository.commit(suffixed_sha_from)
  end

  def commit_to
    @commit_to ||= project.repository.commit(sha_to)
  end

  private

  def suffixed_sha_from
    sha_from + (exclude_start? ? '^' : '')
  end
end
