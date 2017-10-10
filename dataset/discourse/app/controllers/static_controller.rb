require_dependency 'distributed_memoizer'
require_dependency 'file_helper'

class StaticController < ApplicationController

  skip_before_filter :check_xhr, :redirect_to_login_if_required
  skip_before_filter :verify_authenticity_token, only: [:cdn_asset, :enter, :favicon]

  def show
    return redirect_to(path '/') if current_user && params[:id] == 'login'

    map = {
      "faq" => {redirect: "faq_url", topic_id: "guidelines_topic_id"},
      "tos" => {redirect: "tos_url", topic_id: "tos_topic_id"},
      "privacy" => {redirect: "privacy_policy_url", topic_id: "privacy_topic_id"}
    }

    @page = params[:id]

    if map.has_key?(@page)
      site_setting_key = map[@page][:redirect]
      #nodyna <send-452> <SD COMPLEX (change-prone variables)>
      url = SiteSetting.send(site_setting_key)
      return redirect_to(url) unless url.blank?
    end

    @page = 'faq' if @page == 'guidelines'

    @page.gsub!(/[^a-z0-9\_\-]/, '')

    if map.has_key?(@page)
      #nodyna <send-453> <SD COMPLEX (change-prone variables)>
      @topic = Topic.find_by_id(SiteSetting.send(map[@page][:topic_id]))
      raise Discourse::NotFound unless @topic
      @title = @topic.title
      @body = @topic.posts.first.cooked
      @faq_overriden = !SiteSetting.faq_url.blank?
      render :show, layout: !request.xhr?, formats: [:html]
      return
    end

    if I18n.exists?("static.#{@page}")
      render text: I18n.t("static.#{@page}"), layout: !request.xhr?, formats: [:html]
      return
    end

    file = "static/#{@page}.#{I18n.locale}"
    file = "static/#{@page}.en" if lookup_context.find_all("#{file}.html").empty?
    file = "static/#{@page}"    if lookup_context.find_all("#{file}.html").empty?

    if lookup_context.find_all("#{file}.html").any?
      render file, layout: !request.xhr?, formats: [:html]
      return
    end

    raise Discourse::NotFound
  end

  def enter
    params.delete(:username)
    params.delete(:password)

    destination = path("/")

    if params[:redirect].present? && !params[:redirect].match(login_path)
      begin
        forum_uri = URI(Discourse.base_url)
        uri = URI(params[:redirect])

        if uri.path.present? &&
           (uri.host.blank? || uri.host == forum_uri.host) &&
           uri.path !~ /\./

          destination = uri.path
          destination = "#{uri.path}?#{uri.query}" if uri.path =~ /new-topic/
        end
      rescue URI::InvalidURIError
      end
    end

    redirect_to destination
  end

  def favicon

    data = DistributedMemoizer.memoize('favicon' + SiteSetting.favicon_url, 60*30) do
      begin
        file = FileHelper.download(SiteSetting.favicon_url, 50.kilobytes, "favicon.png")
        data = file.read
        file.unlink
        data
      rescue => e
        Rails.logger.warn("Invalid favicon_url #{SiteSetting.favicon_url}: #{e}\n#{e.backtrace}")
        ""
      end
    end

    if data.bytesize == 0
      render text: UserAvatarsController::DOT, content_type: "image/gif"
    else
      expires_in 1.year, public: true
      response.headers["Expires"] = 1.year.from_now.httpdate
      response.headers["Content-Length"] = data.bytesize.to_s
      response.headers["Last-Modified"] = Time.new('2000-01-01').httpdate
      render text: data, content_type: "image/png"
    end

  end


  def cdn_asset
    path = File.expand_path(Rails.root + "public/assets/" + params[:path])

    raise Discourse::NotFound unless path.start_with?(Rails.root.to_s + "/public/assets")

    expires_in 1.year, public: true

    response.headers["Expires"] = 1.year.from_now.httpdate
    response.headers["Access-Control-Allow-Origin"] = params[:origin] if params[:origin]

    begin
      response.headers["Last-Modified"] = File.ctime(path).httpdate
      response.headers["Content-Length"] = File.size(path).to_s
    rescue Errno::ENOENT
      raise Discourse::NotFound
    end

    opts = { disposition: nil }
    opts[:type] = "application/javascript" if path =~ /\.js$/

    request.env['sendfile.type'] = ''
    send_file(path, opts)
  end

end
