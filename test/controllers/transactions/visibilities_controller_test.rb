require "test_helper"

class Transactions::VisibilitiesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @owner = users(:family_admin)
    @member = users(:family_member)
    @entry = entries(:transaction)
    @entry.update!(name: "Secret Necklace Shop", amount: 123.45)
  end

  test "a member hides and unhides their own transaction" do
    sign_in @owner

    patch transaction_visibility_url(@entry), params: { entry: { hidden: "1" } }
    assert_redirected_to transactions_url
    assert_equal @owner, @entry.reload.hidden_by

    patch transaction_visibility_url(@entry), params: { entry: { hidden: "0" } }
    assert_nil @entry.reload.hidden_by
  end

  test "the owner sees their hidden transaction masked behind the eye toggle" do
    @entry.hide_from_household!(@owner)
    sign_in @owner

    get transactions_url

    assert_response :success
    assert_select "##{dom_id(@entry)} [data-controller~='hidden-entry']" do
      assert_select "[data-hidden-entry-target='masked']", text: I18n.t("transactions.transaction.hidden_name")
      assert_select "[data-hidden-entry-target='revealed'].hidden", text: "Secret Necklace Shop"
      assert_select "button[data-action='hidden-entry#toggle']", count: 2
    end
  end

  test "another member with access to the account never receives a hidden transaction" do
    @entry.hide_from_household!(@owner)
    sign_in @member

    get transactions_url
    assert_response :success
    assert_no_match "Secret Necklace Shop", response.body
    assert_no_match "123.45", response.body

    get transactions_url(q: { search: "Necklace" })
    assert_no_match "Secret Necklace Shop", response.body

    get account_url(@entry.account)
    assert_no_match "Secret Necklace Shop", response.body

    get transaction_url(@entry)
    assert_response :not_found
  end

  test "another member can't unhide or re-hide a hidden transaction" do
    @entry.hide_from_household!(@owner)
    sign_in @member

    patch transaction_visibility_url(@entry), params: { entry: { hidden: "0" } }

    assert_response :not_found
    assert_equal @owner, @entry.reload.hidden_by
  end

  test "transfers can't be hidden" do
    sign_in @owner
    transfer_entry = entries(:transfer_out)
    transfer_entry.entryable.update!(kind: "funds_movement")

    patch transaction_visibility_url(transfer_entry), params: { entry: { hidden: "1" } }

    assert_response :unprocessable_entity
    assert_nil transfer_entry.reload.hidden_by
  end
end
