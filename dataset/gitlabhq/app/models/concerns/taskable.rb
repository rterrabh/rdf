require 'task_list'
require 'task_list/filter'

module Taskable
  def task_list_items
    return [] if description.blank?

    @task_list_items ||= description.scan(TaskList::Filter::ItemPattern).collect do |item|
      TaskList::Item.new("- #{item}")
    end
  end

  def tasks
    @tasks ||= TaskList.new(self)
  end

  def tasks?
    tasks.summary.items?
  end

  def task_status
    return '' if description.blank?

    sum = tasks.summary
    "#{sum.item_count} tasks (#{sum.complete_count} completed, #{sum.incomplete_count} remaining)"
  end
end
