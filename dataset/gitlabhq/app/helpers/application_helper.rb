require 'digest/md5'
require 'uri'

module ApplicationHelper
  def current_controller?(*args)
    args.any? { |v| v.to_s.downcase == controller.controller_name }
  end

  def current_action?(*args)
    args.any? { |v| v.to_s.downcase == action_name }
  end

  def project_icon(project_id, options = {})
    project =
      if project_id.is_a?(Project)
        project = project_id
      else
        Project.find_with_namespace(project_id)
      end

    if project.avatar_url
      image_tag project.avatar_url, options
    else # generated icon
      project_identicon(project, options)
    end
  end

  def project_identicon(project, options = {})
    allowed_colors = {
      red: 'FFEBEE',
      purple: 'F3E5F5',
      indigo: 'E8EAF6',
      blue: 'E3F2FD',
      teal: 'E0F2F1',
      orange: 'FBE9E7',
      gray: 'EEEEEE'
    }

    options[:class] ||= ''
    options[:class] << ' identicon'
    bg_key = project.id % 7
    style = "background-color: ##{ allowed_colors.values[bg_key] }; color: #555"

    content_tag(:div, class: options[:class], style: style) do
      project.name[0, 1].upcase
    end
  end

  def avatar_icon(user_email = '', size = nil)
    user = User.find_by(email: user_email)

    if user
      user.avatar_url(size) || default_avatar
    else
      gravatar_icon(user_email, size)
    end
  end

  def gravatar_icon(user_email = '', size = nil)
    GravatarService.new.execute(user_email, size) ||
      default_avatar
  end

  def default_avatar
    image_path('no_avatar.png')
  end

  def last_commit(project)
    if project.repo_exists?
      time_ago_with_tooltip(project.repository.commit.committed_date)
    else
      'Never'
    end
  rescue
    'Never'
  end

  def grouped_options_refs
    repository = @project.repository

    options = [
      ['Branches', repository.branch_names],
      ['Tags', VersionSorter.rsort(repository.tag_names)]
    ]

    if(@ref && !options.flatten.include?(@ref) &&
       @ref =~ /\A[0-9a-zA-Z]{6,52}\z/)
      options << ['Commit', [@ref]]
    end

    grouped_options_for_select(options, @ref || @project.default_branch)
  end

  def emoji_autocomplete_source
    Emoji.names.to_s
  end

  def show_last_push_widget?(event)
    return false unless event && event.last_push_to_non_root? && !event.rm_ref?

    project = event.project

    return false unless project && !project.empty_repo? && project.merge_requests_enabled

    return false if project.merge_requests.where(source_branch: event.branch_name).opened.any?

    return false unless project.repository.branch_names.include?(event.branch_name)

    true
  end

  def hexdigest(string)
    Digest::SHA1.hexdigest string
  end

  def simple_sanitize(str)
    sanitize(str, tags: %w(a span))
  end

  def body_data_page
    path = controller.controller_path.split('/')
    namespace = path.first if path.second

    [namespace, controller.controller_name, controller.action_name].compact.join(':')
  end

  def gitlab_config
    Gitlab.config.gitlab
  end

  def extra_config
    Gitlab.config.extra
  end

  def search_placeholder
    if @project && @project.persisted?
      'Search in this project'
    elsif @snippet || @snippets || @show_snippets
      'Search snippets'
    elsif @group && @group.persisted?
      'Search in this group'
    else
      'Search'
    end
  end

  def broadcast_message
    BroadcastMessage.current
  end

  def time_ago_with_tooltip(time, placement: 'top', html_class: 'time_ago', skip_js: false)
    element = content_tag :time, time.to_s,
      class: "#{html_class} js-timeago",
      datetime: time.getutc.iso8601,
      title: time.in_time_zone.stamp('Aug 21, 2011 9:23pm'),
      data: { toggle: 'tooltip', placement: placement }

    element += javascript_tag "$('.js-timeago').timeago()" unless skip_js

    element
  end

  def render_markup(file_name, file_content)
    if gitlab_markdown?(file_name)
      Haml::Helpers.preserve(markdown(file_content))
    elsif asciidoc?(file_name)
      asciidoc(file_content)
    elsif plain?(file_name)
      content_tag :pre, class: 'plain-readme' do
        file_content
      end
    else
      GitHub::Markup.render(file_name, file_content).
        force_encoding(file_content.encoding).html_safe
    end
  rescue RuntimeError
    simple_format(file_content)
  end

  def plain?(filename)
    Gitlab::MarkupHelper.plain?(filename)
  end

  def markup?(filename)
    Gitlab::MarkupHelper.markup?(filename)
  end

  def gitlab_markdown?(filename)
    Gitlab::MarkupHelper.gitlab_markdown?(filename)
  end

  def asciidoc?(filename)
    Gitlab::MarkupHelper.asciidoc?(filename)
  end

  def promo_host
    'about.gitlab.com'
  end

  def promo_url
    'https://' + promo_host
  end

  def page_filter_path(options = {})
    without = options.delete(:without)

    exist_opts = {
      state: params[:state],
      scope: params[:scope],
      label_name: params[:label_name],
      milestone_id: params[:milestone_id],
      assignee_id: params[:assignee_id],
      author_id: params[:author_id],
      sort: params[:sort],
    }

    options = exist_opts.merge(options)

    if without.present?
      without.each do |key|
        options.delete(key)
      end
    end

    path = request.path
    path << "?#{options.to_param}"
    path
  end

  def outdated_browser?
    browser.ie? && browser.version.to_i < 10
  end

  def path_to_key(key, admin = false)
    if admin
      admin_user_key_path(@user, key)
    else
      profile_key_path(key)
    end
  end

  def state_filters_text_for(entity, project)
    titles = {
      opened: "Open"
    }

    entity_title = titles[entity] || entity.to_s.humanize

    count =
      if project.nil?
        nil
      elsif current_controller?(:issues)
        #nodyna <send-524> <SD COMPLEX (change-prone variables)>
        project.issues.send(entity).count
      elsif current_controller?(:merge_requests)
        #nodyna <send-525> <SD COMPLEX (change-prone variables)>
        project.merge_requests.send(entity).count
      end

    html = content_tag :span, entity_title

    if count.present?
      html += " "
      html += content_tag :span, number_with_delimiter(count), class: 'badge'
    end

    html.html_safe
  end
end
