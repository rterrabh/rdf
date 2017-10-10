module TabHelper
  def nav_link(options = {}, &block)
    klass = active_nav_link?(options) ? 'active' : ''

    o = options.delete(:html_options) || {}
    o[:class] ||= ''
    o[:class] += ' ' + klass
    o[:class].strip!

    if block_given?
      content_tag(:li, capture(&block), o)
    else
      content_tag(:li, nil, o)
    end
  end

  def active_nav_link?(options)
    if path = options.delete(:path)
      unless path.respond_to?(:each)
        path = [path]
      end

      path.any? do |single_path|
        current_path?(single_path)
      end
    else
      c = options.delete(:controller)
      a = options.delete(:action)

      if c && a
        current_controller?(*c) && current_action?(*a)
      else
        current_controller?(*c) || current_action?(*a)
      end
    end
  end

  def current_path?(path)
    c, a, _ = path.split('#')
    current_controller?(c) && current_action?(a)
  end

  def project_tab_class
    return "active" if current_page?(controller: "/projects", action: :edit, id: @project)

    if ['services', 'hooks', 'deploy_keys', 'protected_branches'].include? controller.controller_name
      "active"
    end
  end

  def branches_tab_class
    if current_controller?(:protected_branches) ||
      current_controller?(:branches) ||
      current_page?(namespace_project_repository_path(@project.namespace,
                                                      @project))
      'active'
    end
  end

  def nav_tab(key, value, &block)
    o = {}
    o[:class] = ""

    if value.nil?
      o[:class] << " active" if params[key].blank?
    else
      o[:class] << " active" if params[key] == value
    end

    if block_given?
      content_tag(:li, capture(&block), o)
    else
      content_tag(:li, nil, o)
    end
  end
end
