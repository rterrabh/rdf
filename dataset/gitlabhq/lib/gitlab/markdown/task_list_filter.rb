require 'task_list/filter'

module Gitlab
  module Markdown
    class TaskListFilter < TaskList::Filter
      def add_css_class(node, *new_class_names)
        if new_class_names.include?('task-list')
          super if node.children.any? { |c| c['class'] == 'task-list-item' }
        else
          super
        end
      end
    end
  end
end
