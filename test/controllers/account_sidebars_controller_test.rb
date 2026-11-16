require "test_helper"

class AccountSidebarsControllerTest < ActionDispatch::IntegrationTest
  include ActionView::RecordIdentifier

  setup do
    sign_in @user = users(:family_admin)
    @account = accounts(:depository)
  end

  test "renders the mobile account sidebar in its frame without the app layout" do
    get account_sidebar_path

    assert_response :success
    assert_select "turbo-frame#mobile_account_sidebar [data-testid='account-sidebar-tabs']"
    assert_select "[id^='mobile_']"
    assert_select "nav", count: 0
  end

  test "highlights the account of the page the sidebar was opened on" do
    get account_sidebar_path(path: account_path(@account))

    assert_response :success
    assert_select "a[href='#{account_path(@account)}'][data-active-account]"
  end

  test "ignores a path that is not an app path" do
    get account_sidebar_path(path: "https://example.com#{account_path(@account)}")

    assert_response :success
    assert_select "a[data-active-account]", count: 0
  end

  test "requires authentication" do
    reset!

    get account_sidebar_path

    assert_redirected_to new_session_path
  end
end
