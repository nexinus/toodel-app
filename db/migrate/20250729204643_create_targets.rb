class CreateTargets < ActiveRecord::Migration[8.0]
  def change
    create_table :targets do |t|
      t.string :name

      t.timestamps
    end
  end
end
