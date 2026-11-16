class AccountSidebarsController < ApplicationController
  def show
    @sidebar_page_path = params[:path] if params[:path].to_s.start_with?("/")

    render layout: false
  end
end
