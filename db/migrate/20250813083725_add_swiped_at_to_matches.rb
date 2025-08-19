class AddSwipedAtToMatches < ActiveRecord::Migration[8.0]
  def change
    add_column :matches, :swiped_at, :datetime
  end
end
