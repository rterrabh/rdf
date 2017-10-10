class WikiPage
  include ActiveModel::Validations
  include ActiveModel::Conversion
  include StaticModel
  extend ActiveModel::Naming

  def self.primary_key
    'slug'
  end

  def self.model_name
    ActiveModel::Name.new(self, nil, 'wiki')
  end

  def to_key
    [:slug]
  end

  validates :title, presence: true
  validates :content, presence: true

  attr_reader :wiki

  attr_reader :page

  attr_accessor :attributes

  def initialize(wiki, page = nil, persisted = false)
    @wiki       = wiki
    @page       = page
    @persisted  = persisted
    @attributes = {}.with_indifferent_access

    set_attributes if persisted?
  end

  def slug
    @attributes[:slug]
  end

  alias_method :to_param, :slug

  def title
    if @attributes[:title]
      @attributes[:title].gsub(/-+/, ' ')
    else
      ""
    end
  end

  def title=(new_title)
    @attributes[:title] = new_title
  end

  def content
    @attributes[:content] ||= if @page
                                @page.raw_data
                              end
  end

  def formatted_content
    @attributes[:formatted_content] ||= if @page
                                          @page.formatted_data
                                        end
  end

  def format
    @attributes[:format] || :markdown
  end

  def message
    version.try(:message)
  end

  def version
    return nil unless persisted?

    @version ||= @page.version
  end

  def versions
    return [] unless persisted?

    @page.versions
  end

  def commit
    versions.first
  end

  def created_at
    @page.version.date
  end

  def historical?
    @page.historical?
  end

  def persisted?
    @persisted == true
  end

  def create(attr = {})
    @attributes.merge!(attr)

    save :create_page, title, content, format, message
  end

  def update(new_content = "", format = :markdown, message = nil)
    @attributes[:content] = new_content
    @attributes[:format] = format

    save :update_page, @page, content, format, message
  end

  def delete
    if wiki.delete_page(@page)
      true
    else
      false
    end
  end

  private

  def set_attributes
    attributes[:slug] = @page.escaped_url_path
    attributes[:title] = @page.title
    attributes[:format] = @page.format
  end

  def save(method, *args)
    project_wiki = wiki
    #nodyna <send-501> <SD MODERATE (change-prone variables)>
    if valid? && project_wiki.send(method, *args)

      page_details = if method == :update_page
                       @page.url_path
                     else
                       title
                     end

      page_title, page_dir = project_wiki.page_title_and_dir(page_details)
      gollum_wiki = project_wiki.wiki
      @page = gollum_wiki.paged(page_title, page_dir)

      set_attributes

      @persisted = true
    else
      errors.add(:base, project_wiki.error_message) if project_wiki.error_message
      @persisted = false
    end
    @persisted
  end
end
