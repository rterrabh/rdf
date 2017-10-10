module ActiveAdmin
  module ViewHelpers

    Dir[File.expand_path('../view_helpers', __FILE__) + "/*.rb"].each{|f| require f }

    include ActiveAdminApplicationHelper
    include AutoLinkHelper
    include BreadcrumbHelper
    include DisplayHelper
    include IconHelper
    include MethodOrProcHelper
    include SidebarHelper
    include FormHelper
    include TitleHelper
    include ViewFactoryHelper
    include FlashHelper

  end
end
