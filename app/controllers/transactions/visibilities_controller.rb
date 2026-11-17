class Transactions::VisibilitiesController < ApplicationController
  def update
    # annotatable_entries leaves out entries other members have hidden, so only
    # the member who hid a transaction can find it here to unhide it.
    entry = Current.annotatable_entries.where(parent_entry_id: nil).find(params[:transaction_id])
    return head :unprocessable_entity unless entry.hideable?

    if ActiveModel::Type::Boolean.new.cast(params.dig(:entry, :hidden))
      entry.hide_from_household!(Current.user)
      notice = t(".hidden")
    else
      entry.unhide!
      notice = t(".unhidden")
    end

    redirect_back_or_to transactions_path, notice: notice
  end
end
