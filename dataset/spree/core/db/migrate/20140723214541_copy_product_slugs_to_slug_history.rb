class CopyProductSlugsToSlugHistory < ActiveRecord::Migration
  def change

	Spree::Product.connection.execute <<-SQL
#nodyna <send-2542> <SD COMPLEX (private methods)>
INSERT INTO #{FriendlyId::Slug.table_name} (slug, sluggable_id, sluggable_type, created_at)
  SELECT slug, id, '#{Spree::Product.to_s}', #{ActiveRecord::Base.send(:sanitize_sql_array, ['?', Time.current])} 
  FROM #{Spree::Product.table_name}
  WHERE slug IS NOT NULL
  ORDER BY id
SQL

  end
end
