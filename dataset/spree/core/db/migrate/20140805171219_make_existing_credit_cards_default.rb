class MakeExistingCreditCardsDefault < ActiveRecord::Migration
  def up
    Spree::CreditCard.where.not(user_id: nil).joins("LEFT OUTER JOIN spree_credit_cards cc2 ON cc2.user_id = spree_credit_cards.user_id AND spree_credit_cards.created_at < cc2.created_at").where("cc2.user_id IS NULL").update_all(default: true)
  end
  def down
  end
end
