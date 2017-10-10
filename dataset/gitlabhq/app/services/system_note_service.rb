class SystemNoteService
  def self.add_commits(noteable, project, author, new_commits, existing_commits = [], oldrev = nil)
    total_count  = new_commits.length + existing_commits.length
    commits_text = "#{total_count} commit".pluralize(total_count)

    body = "Added #{commits_text}:\n\n"
    body << existing_commit_summary(noteable, existing_commits, oldrev)
    body << new_commit_summary(new_commits).join("\n")

    create_note(noteable: noteable, project: project, author: author, note: body)
  end

  def self.change_assignee(noteable, project, author, assignee)
    body = assignee.nil? ? 'Assignee removed' : "Reassigned to @#{assignee.username}"

    create_note(noteable: noteable, project: project, author: author, note: body)
  end

  def self.change_label(noteable, project, author, added_labels, removed_labels)
    labels_count = added_labels.count + removed_labels.count

    references     = ->(label) { "~#{label.id}" }
    added_labels   = added_labels.map(&references).join(' ')
    removed_labels = removed_labels.map(&references).join(' ')

    body = ''

    if added_labels.present?
      body << "added #{added_labels}"
      body << ' and ' if removed_labels.present?
    end

    if removed_labels.present?
      body << "removed #{removed_labels}"
    end

    body << ' ' << 'label'.pluralize(labels_count)
    body = "#{body.capitalize}"

    create_note(noteable: noteable, project: project, author: author, note: body)
  end

  def self.change_milestone(noteable, project, author, milestone)
    body = 'Milestone '
    body += milestone.nil? ? 'removed' : "changed to #{milestone.title}"

    create_note(noteable: noteable, project: project, author: author, note: body)
  end

  def self.change_status(noteable, project, author, status, source)
    body = "Status changed to #{status}"
    body += " by #{source.gfm_reference}" if source

    create_note(noteable: noteable, project: project, author: author, note: body)
  end

  def self.change_title(noteable, project, author, old_title)
    return unless noteable.respond_to?(:title)

    body = "Title changed from **#{old_title}** to **#{noteable.title}**"
    create_note(noteable: noteable, project: project, author: author, note: body)
  end

  def self.change_branch(noteable, project, author, branch_type, old_branch, new_branch)
    body = "#{branch_type} branch changed from `#{old_branch}` to `#{new_branch}`".capitalize
    create_note(noteable: noteable, project: project, author: author, note: body)
  end

  def self.cross_reference(noteable, mentioner, author)
    return if cross_reference_disallowed?(noteable, mentioner)

    gfm_reference = mentioner.gfm_reference(noteable.project)

    note_options = {
      project: noteable.project,
      author:  author,
      note:    cross_reference_note_content(gfm_reference)
    }

    if noteable.kind_of?(Commit)
      note_options.merge!(noteable_type: 'Commit', commit_id: noteable.id)
    else
      note_options.merge!(noteable: noteable)
    end

    create_note(note_options)
  end

  def self.cross_reference?(note_text)
    note_text.start_with?(cross_reference_note_prefix)
  end

  def self.cross_reference_disallowed?(noteable, mentioner)
    return true if noteable.is_a?(ExternalIssue)
    return false unless mentioner.is_a?(MergeRequest)
    return false unless noteable.is_a?(Commit)

    mentioner.commits.include?(noteable)
  end

  def self.cross_reference_exists?(noteable, mentioner)
    notes = Note.system.where(noteable_type: noteable.class)

    if noteable.is_a?(Commit)
      notes = notes.where(commit_id: noteable.id)
    else
      notes = notes.where(noteable_id: noteable.id)
    end

    gfm_reference = mentioner.gfm_reference(noteable.project)
    notes = notes.where(note: cross_reference_note_content(gfm_reference))

    notes.count > 0
  end

  private

  def self.create_note(args = {})
    Note.create(args.merge(system: true))
  end

  def self.cross_reference_note_prefix
    'mentioned in '
  end

  def self.cross_reference_note_content(gfm_reference)
    "#{cross_reference_note_prefix}#{gfm_reference}"
  end

  def self.new_commit_summary(new_commits)
    new_commits.collect do |commit|
      "* #{commit.short_id} - #{commit.title}"
    end
  end

  def self.existing_commit_summary(noteable, existing_commits, oldrev = nil)
    return '' if existing_commits.empty?

    count = existing_commits.size

    commit_ids = if count == 1
                   existing_commits.first.short_id
                 else
                   if oldrev
                     "#{Commit.truncate_sha(oldrev)}...#{existing_commits.last.short_id}"
                   else
                     "#{existing_commits.first.short_id}..#{existing_commits.last.short_id}"
                   end
                 end

    commits_text = "#{count} commit".pluralize(count)

    branch = noteable.target_branch
    branch = "#{noteable.target_project_namespace}:#{branch}" if noteable.for_fork?

    "* #{commit_ids} - #{commits_text} from branch `#{branch}`\n"
  end
end
