class AddRoleSkillsBioToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :role, :string
    add_column :users, :skills, :text
    add_column :users, :bio, :text
  end
end
