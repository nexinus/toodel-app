class AddStudentProfileFieldsToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :university, :string
    add_column :users, :degree_program, :string
    add_column :users, :year_of_study, :integer
    add_column :users, :availability, :text
    add_column :users, :preferred_project_types, :text, array: true, default: []
    add_column :users, :looking_for_teammates, :boolean, default: true
    add_column :users, :hide_last_name, :boolean, default: false
    add_column :users, :github_username, :string
    add_column :users, :linkedin_url, :string
    add_column :users, :portfolio_url, :string
    add_column :users, :timezone, :string
    add_column :users, :communication_preferences, :text, array: true, default: []
    
    # Add indexes for better query performance
    add_index :users, :university
    add_index :users, :degree_program
    add_index :users, :year_of_study
    add_index :users, :preferred_project_types, using: :gin
    add_index :users, :looking_for_teammates
  end
end
