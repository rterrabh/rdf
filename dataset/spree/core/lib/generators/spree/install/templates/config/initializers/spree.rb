Spree.config do |config|
end

Spree.user_class = <%= (options[:user_class].blank? ? "Spree::LegacyUser" : options[:user_class]).inspect %>
