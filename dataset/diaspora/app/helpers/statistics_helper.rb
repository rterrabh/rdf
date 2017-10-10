
module StatisticsHelper
  def registrations_status statistics
    if statistics.open_registrations?
      I18n.t('statistics.open')
    else
      I18n.t('statistics.closed')
    end
  end

  def registrations_status_class statistics
    if statistics.open_registrations?
      "serv-enabled"
    else
      "serv-disabled"
    end
  end

  def service_status service, available_services
    if available_services.include? service.to_s
      I18n.t('statistics.enabled')
    else
      I18n.t('statistics.disabled')
    end
  end

  def service_class service, available_services
    if available_services.include? service.to_s
      "serv-enabled"
    else
      "serv-disabled"
    end
  end
end
