class CreateTeamMemberships < ActiveRecord::Migration[8.0]
  def change
    create_table :team_memberships do |t|
      t.references :user, null: false, foreign_key: true
      t.references :team, null: false, foreign_key: true
      t.string :role, default: 'member' # creator, admin, member
      t.string :status, default: 'active' # active, inactive, removed
      t.datetime :joined_at, null: false
      t.text :contribution_notes
      
      t.timestamps
    end
    
    add_index :team_memberships, [:user_id, :team_id], unique: true
    add_index :team_memberships, :role
    add_index :team_memberships, :status
  end
end
