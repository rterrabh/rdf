module SiteSettings; end

class SiteSettings::DbProvider

  def initialize(model)
    model.after_commit do
      model.notify_changed!
    end

    @model = model
  end

  def all
    return [] unless table_exists?

    SqlBuilder.new("select name, data_type, value from #{@model.table_name}").map_exec(OpenStruct)
  end

  def find(name)
    return nil unless table_exists?

    SqlBuilder.new("select name, data_type, value from #{@model.table_name} where name = :name")
      .map_exec(OpenStruct, name: name)
      .first
  end

  def save(name, value, data_type)

    return unless table_exists?

    model = @model.find_by({
      name: name
    })

    model ||= @model.new

    model.name = name
    model.value =  value
    model.data_type =  data_type

    model.save!

    true
  end

  def destroy(name)
    return unless table_exists?

    @model.where(name: name).destroy_all
  end

  def current_site
    RailsMultisite::ConnectionManagement.current_db
  end

  protected

  def table_exists?
    @table_exists = ActiveRecord::Base.connection.table_exists? @model.table_name unless @table_exists
    @table_exists
  end

end
