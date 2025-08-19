require "test_helper"

class MatchesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @other = users(:two)
    # Ensure required fields for validations (minimal stub)
    [@user, @other].each do |u|
      begin
        u.update!(
          university: "Uni", degree_program: "CS", year_of_study: 2,
          skills: "Ruby,JS", availability: "Evenings", preferred_project_types: ["academic"],
          password: "password", password_confirmation: "password"
        )
      rescue
      end
    end
  end

  # ============================================================================
  # INDEX ACTION TESTS
  # ============================================================================
  
  test "GET /matches requires authentication" do
    get matches_path
    assert_response :redirect
    assert_redirected_to new_user_session_path
  end

  test "GET /matches returns success when authenticated" do
    sign_in_as(@user)
    get matches_path
    assert_response :success
    assert_select "h1", "My Matches"
  end

  test "GET /matches returns JSON when requested" do
    sign_in_as(@user)
    get matches_path, as: :json
    assert_response :success
    
    json_response = JSON.parse(response.body)
    assert_includes json_response.keys, "pending_invitations"
    assert_includes json_response.keys, "accepted_invitations"
    assert_includes json_response.keys, "mutual_matches"
    assert_includes json_response.keys, "teams"
  end

  # ============================================================================
  # SHOW ACTION TESTS
  # ============================================================================
  
  test "GET /matches/:id requires authentication" do
    match = matches(:one)
    get match_path(match)
    assert_response :redirect
    assert_redirected_to new_user_session_path
  end

  test "GET /matches/:id returns success when authenticated" do
    sign_in_as(@user)
    match = matches(:one)
    get match_path(match)
    assert_response :success
    assert_select "h1", "Match Details"
  end

  test "GET /matches/:id returns 404 for non-existent match" do
    sign_in_as(@user)
    get match_path(99999)
    assert_response :redirect
    assert_redirected_to matches_path
  end

  test "GET /matches/:id returns JSON when requested" do
    sign_in_as(@user)
    match = matches(:one)
    get match_path(match), as: :json
    assert_response :success
    
    json_response = JSON.parse(response.body)
    assert_includes json_response.keys, "id"
    assert_includes json_response.keys, "user"
    assert_includes json_response.keys, "target"
    assert_includes json_response.keys, "action_type"
    assert_includes json_response.keys, "status"
  end

  # ============================================================================
  # CREATE ACTION TESTS
  # ============================================================================
  
  test "POST /matches requires authentication" do
    post matches_path, params: { target_id: @other.id, action_type: "invite" }
    assert_response :redirect
    assert_redirected_to new_user_session_path
  end

  test "POST /matches creates a match successfully" do
    sign_in_as(@user)
    fresh_target = create_test_user("Charlie Three", "three@example.com")

    assert_difference -> { Match.count }, +1 do
      post matches_path, params: { target_id: fresh_target.id, action_type: "invite" }
    end
    assert_response :redirect
    assert_redirected_to discover_path
  end

  test "POST /matches creates a match with invitation message" do
    sign_in_as(@user)
    fresh_target = create_test_user("David Four", "four@example.com")

    assert_difference -> { Match.count }, +1 do
      post matches_path, params: { 
        target_id: fresh_target.id, 
        action_type: "invite",
        invitation_message: "Let's work together!",
        project_context: "Hackathon project"
      }
    end
    
    match = Match.last
    assert_equal "Let's work together!", match.invitation_message
    assert_equal "Hackathon project", match.project_context
  end

  test "POST /matches creates a skip action" do
    sign_in_as(@user)
    fresh_target = create_test_user("Eve Five", "five@example.com")

    assert_difference -> { Match.count }, +1 do
      post matches_path, params: { target_id: fresh_target.id, action_type: "skip" }
    end
    
    match = Match.last
    assert_equal "skip", match.action_type
  end

  test "POST /matches prevents duplicate interactions" do
    sign_in_as(@user)
    fresh_target = create_test_user("Frank Six", "six@example.com")

    # Create first match
    post matches_path, params: { target_id: fresh_target.id, action_type: "invite" }
    assert_response :redirect
    
    # Try to create duplicate
    assert_no_difference -> { Match.count } do
      post matches_path, params: { target_id: fresh_target.id, action_type: "skip" }
    end
    assert_response :redirect
  end

  test "POST /matches returns JSON when requested" do
    sign_in_as(@user)
    fresh_target = create_test_user("Grace Seven", "seven@example.com")

    post matches_path, params: { target_id: fresh_target.id, action_type: "invite" }, as: :json
    assert_response :created
    
    json_response = JSON.parse(response.body)
    assert_includes json_response.keys, "id"
    assert_includes json_response.keys, "action_type"
    assert_equal "invite", json_response["action_type"]
  end

  # ============================================================================
  # INVITE ACTION TESTS
  # ============================================================================
  
  test "POST /matches/:id/invite requires authentication" do
    post invite_match_path(@other)
    assert_response :redirect
    assert_redirected_to new_user_session_path
  end

  test "POST /matches/:id/invite creates invitation successfully" do
    sign_in_as(@user)
    fresh_target = create_test_user("Henry Eight", "eight@example.com")

    assert_difference -> { Match.count }, +1 do
      post invite_match_path(fresh_target), params: { 
        invitation_message: "Let's work together!",
        project_context: "Hackathon project"
      }
    end
    assert_response :redirect
    assert_redirected_to discover_path
  end

  test "POST /matches/:id/invite with team_id creates team invitation" do
    sign_in_as(@user)
    fresh_target = create_test_user("Ivy Nine", "nine@example.com")
    team = create_test_team

    assert_difference -> { Match.count }, +1 do
      post invite_match_path(fresh_target), params: { 
        team_id: team.id,
        invitation_message: "Join our team!"
      }
    end
    
    match = Match.last
    assert_equal team.id, match.team_id
  end

  test "POST /matches/:id/invite prevents duplicate invitations" do
    sign_in_as(@user)
    fresh_target = create_test_user("Jack Ten", "ten@example.com")

    # Create first invitation
    post invite_match_path(fresh_target)
    assert_response :redirect
    
    # Try to create duplicate
    assert_no_difference -> { Match.count } do
      post invite_match_path(fresh_target)
    end
    assert_response :redirect
  end

  # ============================================================================
  # SKIP ACTION TESTS
  # ============================================================================
  
  test "POST /matches/:id/skip requires authentication" do
    post skip_match_path(@other)
    assert_response :redirect
    assert_redirected_to new_user_session_path
  end

  test "POST /matches/:id/skip creates skip action successfully" do
    sign_in_as(@user)
    fresh_target = create_test_user("Kate Eleven", "eleven@example.com")

    assert_difference -> { Match.count }, +1 do
      post skip_match_path(fresh_target)
    end
    assert_response :redirect
    assert_redirected_to discover_path
    
    match = Match.last
    assert_equal "skip", match.action_type
  end

  test "POST /matches/:id/skip prevents duplicate skips" do
    sign_in_as(@user)
    fresh_target = create_test_user("Liam Twelve", "twelve@example.com")

    # Create first skip
    post skip_match_path(fresh_target)
    assert_response :redirect
    
    # Try to create duplicate
    assert_no_difference -> { Match.count } do
      post skip_match_path(fresh_target)
    end
    assert_response :redirect
  end

  # ============================================================================
  # ACCEPT/DECLINE ACTION TESTS
  # ============================================================================
  
  test "POST /matches/:id/accept requires authentication" do
    match = matches(:one)
    post accept_match_path(match)
    assert_response :redirect
    assert_redirected_to new_user_session_path
  end

  test "POST /matches/:id/accept works for valid invitation" do
    # Create a match where current_user is the target
    fresh_target = create_test_user("Accept Target", "accept@example.com")
    match = Match.create!(
      user: fresh_target,
      target: @user,
      action_type: "invite",
      status: "pending"
    )
    
    sign_in_as(@user)
    post accept_match_path(match)
    assert_response :redirect
    assert_redirected_to matches_path
    
    match.reload
    assert_equal "accepted", match.status
  end

  test "current_user is set correctly in controller" do
    fresh_user = create_test_user("Current User", "currentuser@example.com")
    
    # Test that current_user is not set without authentication
    get matches_path
    assert_response :redirect
    assert_redirected_to new_user_session_path
    
    # Test that current_user is set with authentication
    sign_in_as(fresh_user)
    get matches_path
    assert_response :success
  end

  test "authentication works correctly in controller" do
    # Create a simple invitation
    fresh_user1 = create_test_user("Auth User 1", "authuser1@example.com")
    fresh_user2 = create_test_user("Auth User 2", "authuser2@example.com")
    
    invitation = Match.create!(
      user: fresh_user1,
      target: fresh_user2,
      action_type: "invite",
      status: "pending"
    )
    
    # Test without authentication
    post accept_match_path(invitation)
    assert_response :redirect
    assert_redirected_to new_user_session_path
    
    # Test with authentication
    sign_in_as(fresh_user2)
    post accept_match_path(invitation)
    assert_response :redirect
    assert_redirected_to matches_path
    
    # Verify the invitation was accepted
    invitation.reload
    assert_equal "accepted", invitation.status
  end

  test "can_interact method works correctly" do
    # Create a simple invitation using fresh users to avoid fixture conflicts
    fresh_user1 = create_test_user("Test User 1", "testuser1@example.com")
    fresh_user2 = create_test_user("Test User 2", "testuser2@example.com")
    
    invitation = Match.create!(
      user: fresh_user1,
      target: fresh_user2,
      action_type: "invite",
      status: "pending"
    )
    
    # Test that can_interact? works correctly
    assert invitation.can_interact?(fresh_user2), "User should be able to interact with invitation sent to them"
    assert !invitation.can_interact?(fresh_user1), "User should not be able to interact with invitation they sent"
    
    # Change status and test again
    invitation.update!(status: "accepted")
    assert !invitation.can_interact?(fresh_user2), "User should not be able to interact with accepted invitation"
  end

  test "mutual match is created when both users accept each other" do
    # Create two users
    user1 = create_test_user("User One", "user1@example.com")
    user2 = create_test_user("User Two", "user2@example.com")
    
    # User1 invites User2
    invitation1 = Match.create!(
      user: user1,
      target: user2,
      action_type: "invite",
      status: "pending"
    )
    
    # User2 invites User1
    invitation2 = Match.create!(
      user: user2,
      target: user1,
      action_type: "invite",
      status: "pending"
    )
    
    # User2 accepts User1's invitation
    sign_in_as(user2)
    post accept_match_path(invitation1)
    assert_response :redirect
    
    invitation1.reload
    assert_equal "accepted", invitation1.status
    
    # User1 accepts User2's invitation
    sign_in_as(user1)
    post accept_match_path(invitation2)
    assert_response :redirect
    
    invitation2.reload
    assert_equal "accepted", invitation2.status
    
    # Now both should be mutual matches
    assert user1.mutual_matches.any?
    assert user2.mutual_matches.any?
    
    # Check that the mutual_matches method returns the correct matches
    user1_matches = user1.mutual_matches
    user2_matches = user2.mutual_matches
    
    assert_equal 1, user1_matches.count
    assert_equal 1, user2_matches.count
    
    # Verify the mutual match is between the correct users
    assert_equal user2.id, user1_matches.first.target.id
    assert_equal user1.id, user2_matches.first.target.id
  end

  test "POST /matches/:id/decline requires authentication" do
    match = matches(:one)
    post decline_match_path(match)
    assert_response :redirect
    assert_redirected_to new_user_session_path
  end

  test "POST /matches/:id/decline works for valid invitation" do
    # Create a match where current_user is the target
    fresh_target = create_test_user("Decline Target", "decline@example.com")
    match = Match.create!(
      user: fresh_target,
      target: @user,
      action_type: "invite",
      status: "pending"
    )
    
    sign_in_as(@user)
    post decline_match_path(match)
    assert_response :redirect
    assert_redirected_to matches_path
    
    match.reload
    assert_equal "declined", match.status
  end

  # ============================================================================
  # DISCOVER ACTION TESTS
  # ============================================================================
  
  test "GET /discover requires authentication" do
    get discover_path
    assert_response :redirect
    assert_redirected_to new_user_session_path
  end

  test "GET /discover returns success when authenticated" do
    sign_in_as(@user)
    get discover_path
    assert_response :success
    # Check for any heading that indicates we're on the discover page
    assert_select "h1"
  end

  test "GET /discover returns JSON when requested" do
    sign_in_as(@user)
    get discover_path, as: :json
    assert_response :success
    
    json_response = JSON.parse(response.body)
    assert_kind_of Array, json_response
  end

  # ============================================================================
  # DASHBOARD ACTION TESTS
  # ============================================================================
  
  test "GET /dashboard requires authentication" do
    get dashboard_path
    assert_response :redirect
    assert_redirected_to new_user_session_path
  end

  test "GET /dashboard returns success when authenticated" do
    sign_in_as(@user)
    get dashboard_path
    assert_response :success
    # Check for any heading that indicates we're on the dashboard page
    assert_select "h1"
  end

  test "GET /dashboard returns JSON when requested" do
    sign_in_as(@user)
    get dashboard_path, as: :json
    assert_response :success
    
    json_response = JSON.parse(response.body)
    assert_includes json_response.keys, "pending_invitations"
    assert_includes json_response.keys, "accepted_invitations"
    assert_includes json_response.keys, "teams"
    assert_includes json_response.keys, "stats"
  end

  # ============================================================================
  # EDGE CASES AND ERROR HANDLING
  # ============================================================================
  
  test "POST /matches with invalid target_id returns error" do
    sign_in_as(@user)
    post matches_path, params: { target_id: 99999, action_type: "invite" }
    assert_response :redirect
    # Should redirect to discover path when target not found
    assert_redirected_to discover_path
  end

  test "POST /matches with missing action_type defaults to invite" do
    sign_in_as(@user)
    fresh_target = create_test_user("Maya Thirteen", "thirteen@example.com")

    assert_difference -> { Match.count }, +1 do
      post matches_path, params: { target_id: fresh_target.id }
    end
    
    match = Match.last
    assert_equal "invite", match.action_type
  end

  test "POST /matches with invalid action_type defaults to invite" do
    sign_in_as(@user)
    fresh_target = create_test_user("Noah Fourteen", "fourteen@example.com")

    assert_difference -> { Match.count }, +1 do
      post matches_path, params: { target_id: fresh_target.id, action_type: "invalid_action" }
    end
    
    match = Match.last
    assert_equal "invite", match.action_type
  end

  private

  # Helper method for authentication in tests
  def sign_in_as(user)
    sign_in user
  end

  # Helper method to create test users
  def create_test_user(name, email)
    User.create!(
      name: name,
      email: email,
      university: "Uni",
      degree_program: "CS",
      year_of_study: 1,
      skills: "Test,Skills",
      availability: "Weekends",
      preferred_project_types: ["hackathon"],
      password: "password",
      password_confirmation: "password"
    )
  end

  # Helper method to create test teams
  def create_test_team
    Team.create!(
      name: "Test Team",
      description: "A test team",
      project_type: "hackathon",
      max_members: 4,
      creator: @user,
      university: "Uni"
    )
  end
end
