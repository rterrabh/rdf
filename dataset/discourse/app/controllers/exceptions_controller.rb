class ExceptionsController < ApplicationController
  skip_before_filter :check_xhr, :preload_json

  def not_found
    @hide_google = true if SiteSetting.login_required

    raise Discourse::NotFound
  end

  def not_found_body

    @hide_google = true

    render text: build_not_found_page(200, false)
  end

end
