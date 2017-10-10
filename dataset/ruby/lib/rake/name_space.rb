
class Rake::NameSpace


  def initialize(task_manager, scope_list)
    @task_manager = task_manager
    @scope = scope_list.dup
  end


  def [](name)
    @task_manager.lookup(name, @scope)
  end


  def scope
    @scope.dup
  end


  def tasks
    @task_manager.tasks_in_scope(@scope)
  end

end

