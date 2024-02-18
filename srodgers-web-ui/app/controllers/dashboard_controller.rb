class DashboardController < ApplicationController
  def index
    @bets = Bet.all
    profit = @bets.where(status: "WIN").pluck(:stake).sum
    loss = @bets.where(status: "LOSS").pluck(:stake).sum
    @profit_loss = (profit - loss).round(2)
    @account_balance = ExchangeService.new.get_account_balance
  end
end