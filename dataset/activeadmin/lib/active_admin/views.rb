module ActiveAdmin
  module Views

    Dir[File.expand_path('../views', __FILE__) + "/**/*.rb"].sort.each{ |f| require f }

  end
end
