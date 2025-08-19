class UpdateMatchesForTeamInvitations < ActiveRecord::Migration[8.0]
  def change
    # Rename kind to action_type for clarity
    rename_column :matches, :kind, :action_type
    
    # Add new fields for team invitations
    add_column :matches, :team_id, :bigint
    add_column :matches, :invitation_message, :text
    add_column :matches, :project_context, :text
    add_column :matches, :status, :string, default: 'pending' # pending, accepted, declined, withdrawn
    
    # Add foreign key for team
    add_foreign_key :matches, :teams, column: :team_id
    
    # Add indexes
    add_index :matches, :team_id
    add_index :matches, :action_type
    add_index :matches, :status
    
    # Update existing data
    reversible do |dir|
      dir.up do
        # Convert existing 'connect' to 'invite' and 'pass' to 'skip'
        execute "UPDATE matches SET action_type = 'invite' WHERE action_type = 'connect'"
        execute "UPDATE matches SET action_type = 'skip' WHERE action_type = 'pass'"
      end
      
      dir.down do
        # Convert back if needed
        execute "UPDATE matches SET action_type = 'connect' WHERE action_type = 'invite'"
        execute "UPDATE matches SET action_type = 'pass' WHERE action_type = 'skip'"
      end
    end
  end
end
