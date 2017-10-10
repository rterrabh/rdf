module CommitsHelper
  def commit_author_link(commit, options = {})
    commit_person_link(commit, options.merge(source: :author))
  end

  def commit_committer_link(commit, options = {})
    commit_person_link(commit, options.merge(source: :committer))
  end

  def image_diff_class(diff)
    if diff.deleted_file
      "deleted"
    elsif diff.new_file
      "added"
    else
      nil
    end
  end

  def commit_to_html(commit, project, inline = true)
    template = inline ? "inline_commit" : "commit"
    escape_javascript(render "projects/commits/#{template}", commit: commit, project: project) unless commit.nil?
  end

  def commits_breadcrumbs
    return unless @project && @ref

    crumbs = content_tag(:li) do
      link_to(
        @project.path,
        namespace_project_commits_path(@project.namespace, @project, @ref)
      )
    end

    if @path
      parts = @path.split('/')

      parts.each_with_index do |part, i|
        crumbs << content_tag(:li) do
          link_to(
            part,
            namespace_project_commits_path(
              @project.namespace,
              @project,
              tree_join(@ref, parts[0..i].join('/'))
            )
          )
        end
      end
    end

    crumbs.html_safe
  end

  def commit_default_branch(project, branches)
    branches.include?(project.default_branch) ? branches.delete(project.default_branch) : branches.pop
  end

  def commit_branches_links(project, branches)
    branches.sort.map do |branch|
      link_to(
        namespace_project_tree_path(project.namespace, project, branch)
      ) do
        content_tag :span, class: 'label label-gray' do
          icon('code-fork') + ' ' + branch
        end
      end
    end.join(" ").html_safe
  end

  def commit_tags_links(project, tags)
    sorted = VersionSorter.rsort(tags)
    sorted.map do |tag|
      link_to(
        namespace_project_commits_path(project.namespace, project,
                                       project.repository.find_tag(tag).name)
      ) do
        content_tag :span, class: 'label label-gray' do
          icon('tag') + ' ' + tag
        end
      end
    end.join(" ").html_safe
  end

  def link_to_browse_code(project, commit)
    if current_controller?(:projects, :commits)
      if @repo.blob_at(commit.id, @path)
        return link_to(
          "Browse File »",
          namespace_project_blob_path(project.namespace, project,
                                      tree_join(commit.id, @path)),
          class: "pull-right"
        )
      elsif @path.present?
        return link_to(
          "Browse Dir »",
          namespace_project_tree_path(project.namespace, project,
                                      tree_join(commit.id, @path)),
          class: "pull-right"
        )
      end
    end
    link_to(
      "Browse Code »",
      namespace_project_tree_path(project.namespace, project, commit),
      class: "pull-right"
    )
  end

  protected

  def commit_person_link(commit, options = {})
    #nodyna <send-526> <SD MODERATE (change-prone variables)>
    user = commit.send(options[:source])
    
    #nodyna <send-527> <SD MODERATE (change-prone variables)>
    source_name = clean(commit.send "#{options[:source]}_name".to_sym)
    #nodyna <send-528> <SD MODERATE (change-prone variables)>
    source_email = clean(commit.send "#{options[:source]}_email".to_sym)

    person_name = user.try(:name) || source_name
    person_email = user.try(:email) || source_email

    text =
      if options[:avatar]
        avatar = image_tag(avatar_icon(person_email, options[:size]), class: "avatar #{"s#{options[:size]}" if options[:size]}", width: options[:size], alt: "")
        %Q{#{avatar} <span class="commit-#{options[:source]}-name">#{person_name}</span>}
      else
        person_name
      end

    options = {
      class: "commit-#{options[:source]}-link has_tooltip",
      data: { :'original-title' => sanitize(source_email) }
    }

    if user.nil?
      mail_to(source_email, text.html_safe, options)
    else
      link_to(text.html_safe, user_path(user), options)
    end
  end

  def view_file_btn(commit_sha, diff, project)
    link_to(
      namespace_project_blob_path(project.namespace, project,
                                  tree_join(commit_sha, diff.new_path)),
      class: 'btn btn-small view-file js-view-file'
    ) do
      raw('View file @') + content_tag(:span, commit_sha[0..6],
                                       class: 'commit-short-id')
    end
  end

  def truncate_sha(sha)
    Commit.truncate_sha(sha)
  end

  def clean(string)
    Sanitize.clean(string, remove_contents: true)
  end
end
