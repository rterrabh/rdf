module JobsHelper

  def status(job)
    case
    when job.failed_at
      content_tag :span, 'failed', class: 'label label-danger'
    when job.locked_at && job.locked_by
      content_tag :span, 'running', class: 'label label-info'
    else
      content_tag :span, 'queued', class: 'label label-warning'
    end
  end

  def relative_distance_of_time_in_words(time)
    if time < (now = Time.now)
      time_ago_in_words(time) + ' ago'
    else
      'in ' + distance_of_time_in_words(time, now)
    end
  end

  def agent_from_job(job)
    if data = YAML.load(job.handler).try(:job_data)
      Agent.find_by_id(data['arguments'][0])
    else
      false
    end
  rescue ArgumentError
    nil
  end
end
