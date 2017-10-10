require_dependency 'url_helper'
require_dependency 'file_helper'

module Jobs

  class PullHotlinkedImages < Jobs::Base
    def initialize
      @max_size = SiteSetting.max_image_size_kb.kilobytes
    end

    def execute(args)
      return unless SiteSetting.download_remote_images_to_local?

      post_id = args[:post_id]
      raise Discourse::InvalidParameters.new(:post_id) unless post_id.present?

      post = Post.find_by(id: post_id)
      return unless post.present?

      raw = post.raw.dup
      start_raw = raw.dup
      downloaded_urls = {}

      extract_images_from(post.cooked).each do |image|
        src = image['src']
        src = "http:" + src if src.start_with?("//")

        if is_valid_image_url(src)
          hotlinked = nil
          begin
            unless downloaded_urls.include?(src)
              begin
                hotlinked = FileHelper.download(src, @max_size, "discourse-hotlinked", true)
              rescue Discourse::InvalidParameters
              end
              if hotlinked
                if File.size(hotlinked.path) <= @max_size
                  filename = File.basename(URI.parse(src).path)
                  upload = Upload.create_for(post.user_id, hotlinked, filename, File.size(hotlinked.path), { origin: src })
                  downloaded_urls[src] = upload.url
                else
                  Rails.logger.info("Failed to pull hotlinked image for post: #{post_id}: #{src} - Image is bigger than #{@max_size}")
                end
              else
                Rails.logger.error("There was an error while downloading '#{src}' locally for post: #{post_id}")
              end
            end
            if downloaded_urls[src].present?
              url = downloaded_urls[src]
              escaped_src = Regexp.escape(src)
              raw.gsub!(/src=["']#{escaped_src}["']/i, "src='#{url}'")
              raw.gsub!(/\[img\]#{escaped_src}\[\/img\]/i, "[img]#{url}[/img]")
              raw.gsub!(/\[!\[([^\]]*)\]\(#{escaped_src}\)\]/) { "[<img src='#{url}' alt='#{$1}'>]" }
              raw.gsub!(/!\[([^\]]*)\]\(#{escaped_src}\)/) { "![#{$1}](#{url})" }
              raw.gsub!(/\[(\d+)\]: #{escaped_src}/) { "[#{$1}]: #{url}" }
              raw.gsub!(src, "<img src='#{url}'>")
            end
          rescue => e
            Rails.logger.info("Failed to pull hotlinked image: #{src} post:#{post_id}\n" + e.message + "\n" + e.backtrace.join("\n"))
          ensure
            hotlinked && hotlinked.close!
          end
        end

      end

      post.reload
      if start_raw != post.raw
        backoff = args.fetch(:backoff, 1) + 1
        delay = SiteSetting.ninja_edit_window * args[:backoff]
        Jobs.enqueue_in(delay.seconds.to_i, :pull_hotlinked_images, args.merge!(backoff: backoff))
      elsif raw != post.raw
        changes = { raw: raw, edit_reason: I18n.t("upload.edit_reason") }
        options = { bypass_bump: true }
        post.revise(Discourse.system_user, changes, options)
      end
    end

    def extract_images_from(html)
      doc = Nokogiri::HTML::fragment(html)
      doc.css("img[src]") - doc.css(".onebox-result img") - doc.css("img.avatar")
    end

    def is_valid_image_url(src)
      return false unless src.present?
      return false if Discourse.store.has_been_uploaded?(src)
      return false if src =~ /\A\/[^\/]/i
      begin
        uri = URI.parse(src)
      rescue URI::InvalidURIError
        return false
      end
      return false if Discourse.asset_host.present? && URI.parse(Discourse.asset_host).hostname == uri.hostname
      return false if SiteSetting.s3_cdn_url.present? && URI.parse(SiteSetting.s3_cdn_url).hostname == uri.hostname
      return false if URI.parse(Discourse.base_url_no_prefix).hostname == uri.hostname
      SiteSetting.should_download_images?(src)
    end

  end

end
