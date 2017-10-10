class RemoveTokenPermissionsTable < ActiveRecord::Migration
  def change
    drop_table :spree_tokenized_permissions
  end
end
