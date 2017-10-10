module LabelsHelper
  include ActionView::Helpers::TagHelper

  def link_to_label(label, project: nil, &block)
    project ||= @project || label.project
    link = namespace_project_issues_path(project.namespace, project,
                                         label_name: label.name)

    if block_given?
      link_to link, &block
    else
      link_to render_colored_label(label), link
    end
  end

  def project_label_names
    @project.labels.pluck(:title)
  end

  def render_colored_label(label)
    label_color = label.color || Label::DEFAULT_COLOR
    text_color = text_color_for_bg(label_color)

    span = %(<span class="label color-label") +
      %( style="background-color: #{label_color}; color: #{text_color}">) +
      escape_once(label.name) + '</span>'

    span.html_safe
  end

  def suggested_colors
    [
      '#0033CC',
      '#428BCA',
      '#44AD8E',
      '#A8D695',
      '#5CB85C',
      '#69D100',
      '#004E00',
      '#34495E',
      '#7F8C8D',
      '#A295D6',
      '#5843AD',
      '#8E44AD',
      '#FFECDB',
      '#AD4363',
      '#D10069',
      '#CC0033',
      '#FF0000',
      '#D9534F',
      '#D1D100',
      '#F0AD4E',
      '#AD8D43'
    ]
  end

  def text_color_for_bg(bg_color)
    r, g, b = bg_color.slice(1,7).scan(/.{2}/).map(&:hex)

    if (r + g + b) > 500
      '#333333'
    else
      '#FFFFFF'
    end
  end

  def project_labels_options(project)
    options_from_collection_for_select(project.labels, 'name', 'name', params[:label_name])
  end

  module_function :render_colored_label, :text_color_for_bg, :escape_once
end
