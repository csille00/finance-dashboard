require "application_system_test_case"

class MobileAccountSidebarTest < ApplicationSystemTestCase
  PHONE = [ 375, 812 ].freeze

  setup do
    sign_in @user = users(:family_admin)
    @account = accounts(:depository)
  end

  teardown do
    page.driver.browser.execute_cdp("Emulation.clearDeviceMetricsOverride")
  end

  test "the phone sidebar loads when opened and navigates the whole page" do
    page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride", width: PHONE[0], height: PHONE[1], deviceScaleFactor: 1, mobile: true)
    visit account_url(@account)

    assert_selector "turbo-frame#mobile_account_sidebar:not([complete])", visible: :all

    find("[data-action='app-layout#openMobileSidebar']").click

    within "turbo-frame#mobile_account_sidebar" do
      assert_selector "a[href='#{account_path(@account)}'][data-active-account]"
      click_link accounts(:connected).name
    end

    assert_current_path account_path(accounts(:connected))
    assert_selector "turbo-frame#mobile_account_sidebar", visible: :hidden
  end
end
