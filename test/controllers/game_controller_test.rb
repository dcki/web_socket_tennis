class GameControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get game_path
    assert_redirected_to(controller: 'sessions', action: 'new')
  end
end
