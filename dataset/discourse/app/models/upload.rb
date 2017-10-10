require "digest/sha1"
require_dependency "image_sizer"
require_dependency "file_helper"
require_dependency "url_helper"
require_dependency "db_helper"
require_dependency "validators/upload_validator"
require_dependency "file_store/local_store"

class Upload < ActiveRecord::Base
  belongs_to :user

  has_many :post_uploads, dependent: :destroy
  has_many :posts, through: :post_uploads

  has_many :optimized_images, dependent: :destroy

  validates_presence_of :filesize
  validates_presence_of :original_filename

  validates_with ::Validators::UploadValidator

  def thumbnail(width = self.width, height = self.height)
    optimized_images.find_by(width: width, height: height)
  end

  def has_thumbnail?(width, height)
    thumbnail(width, height).present?
  end

  def create_thumbnail!(width, height)
    return unless SiteSetting.create_thumbnails?
    thumbnail = OptimizedImage.create_for(self, width, height, allow_animation: SiteSetting.allow_animated_thumbnails)
    if thumbnail
      optimized_images << thumbnail
      self.width = width
      self.height = height
      save(validate: false)
    end
  end

  def destroy
    Upload.transaction do
      Discourse.store.remove_upload(self)
      super
    end
  end

  def extension
    File.extname(original_filename)
  end

  CROPPED_IMAGE_TYPES ||= ["avatar", "profile_background", "card_background"]

  def self.create_for(user_id, file, filename, filesize, options = {})
    DistributedMutex.synchronize("upload_#{user_id}_#{filename}") do
      if FileHelper.is_image?(filename)
        if filename =~ /\.svg$/i
          svg = Nokogiri::XML(file).at_css("svg")
          w = svg["width"].to_i
          h = svg["height"].to_i
        else
          fix_image_orientation(file.path) unless filename =~ /\.GIF$/i
          image_info = FastImage.new(file) rescue nil
          w, h = *(image_info.try(:size) || [0, 0])
        end

        width, height = ImageSizer.resize(w, h)

        file.rewind

        if CROPPED_IMAGE_TYPES.include?(options[:image_type])
          allow_animation = SiteSetting.allow_animated_thumbnails
          max_pixel_ratio = Discourse::PIXEL_RATIOS.max

          case options[:image_type]
          when "avatar"
            allow_animation = SiteSetting.allow_animated_avatars
            width = height = Discourse.avatar_sizes.max
          when "profile_background"
            max_width = 850 * max_pixel_ratio
            width, height = ImageSizer.resize(w, h, max_width: max_width, max_height: max_width)
          when "card_background"
            max_width = 590 * max_pixel_ratio
            width, height = ImageSizer.resize(w, h, max_width: max_width, max_height: max_width)
          end

          OptimizedImage.resize(file.path, file.path, width, height, allow_animation: allow_animation)
        end

        ImageOptim.new.optimize_image!(file.path) rescue nil
      end

      sha1 = Digest::SHA1.file(file).hexdigest

      upload = find_by(sha1: sha1)

      if upload && upload.url.blank?
        upload.destroy
        upload = nil
      end

      return upload unless upload.nil?

      upload = Upload.new
      upload.user_id           = user_id
      upload.original_filename = filename
      upload.filesize          = filesize
      upload.sha1              = sha1
      upload.url               = ""
      upload.width             = width
      upload.height            = height
      upload.origin            = options[:origin][0...1000] if options[:origin]

      if FileHelper.is_image?(filename) && (upload.width == 0 || upload.height == 0)
        upload.errors.add(:base, I18n.t("upload.images.size_not_found"))
      end

      return upload unless upload.save

      File.open(file.path) do |f|
        url = Discourse.store.store_upload(f, upload, options[:content_type])
        if url.present?
          upload.url = url
          upload.save
        else
          upload.errors.add(:url, I18n.t("upload.store_failure", { upload_id: upload.id, user_id: user_id }))
        end
      end

      upload
    end
  end

  def self.get_from_url(url)
    return if url.blank?
    url = url.sub(/^#{Discourse.asset_host}/i, "") if Discourse.asset_host.present?
    url = url.sub(/^#{SiteSetting.s3_cdn_url}/i, Discourse.store.absolute_base_url) if SiteSetting.s3_cdn_url.present?
    Upload.find_by(url: url)
  end

  def self.fix_image_orientation(path)
    `convert #{path} -auto-orient #{path}`
  end

  def self.migrate_to_new_scheme(limit=50)
    problems = []

    if SiteSetting.migrate_to_new_scheme
      max_file_size_kb = [SiteSetting.max_image_size_kb, SiteSetting.max_attachment_size_kb].max.kilobytes
      local_store = FileStore::LocalStore.new

      Upload.where("url NOT LIKE '%/original/_X/%'")
            .limit(limit)
            .order(id: :desc)
            .each do |upload|
        begin
          previous_url = upload.url.dup
          external = previous_url =~ /^\/\//
          if external
            url = SiteSetting.scheme + ":" + previous_url
            file = FileHelper.download(url, max_file_size_kb, "discourse", true) rescue nil
            path = file.path
          else
            path = local_store.path_for(upload)
          end
          if upload.sha1.blank?
            upload.sha1 = Digest::SHA1.file(path).hexdigest
          end
          if FileHelper.is_image?(File.basename(path))
            ImageOptim.new.optimize_image!(path)
          end
          File.open(path) do |f|
            upload.url = Discourse.store.store_upload(f, upload)
            upload.filesize = f.size
            upload.save
          end
          DbHelper.remap(UrlHelper.absolute(previous_url), upload.url) unless external
          DbHelper.remap(previous_url, upload.url)
          unless external
            FileUtils.rm(path, force: true) rescue nil
          end
        rescue => e
          problems << { upload: upload, ex: e }
        ensure
          file.try(:unlink) rescue nil
          file.try(:close) rescue nil
        end
      end
    end

    problems
  end

end

