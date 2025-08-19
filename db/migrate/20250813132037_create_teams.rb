class CreateTeams < ActiveRecord::Migration[8.0]
  def change
    create_table :teams do |t|
      t.string :name, null: false
      t.text :description
      t.string :project_type
      t.string :status, default: 'forming' # forming, active, completed, archived
      t.integer :max_members, default: 5
      t.references :creator, null: false, foreign_key: { to_table: :users }
      t.string :university
      t.text :required_skills, array: true, default: []
      t.text :tags, array: true, default: []
      t.datetime :project_deadline
      t.string :meeting_schedule
      t.text :communication_channels, array: true, default: []
      
      t.timestamps
    end
    
    add_index :teams, :project_type
    add_index :teams, :status
    add_index :teams, :university
    add_index :teams, :required_skills, using: :gin
    add_index :teams, :tags, using: :gin
  end
end
