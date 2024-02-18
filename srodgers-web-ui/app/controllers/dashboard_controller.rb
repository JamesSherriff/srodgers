class DashboardController < ApplicationController
  def index
    dt = DateTime.now - 10.hours
    @bets = Bet.all
    profit = @bets.where(status: "WIN").pluck(:stake).sum
    loss = @bets.where(status: "LOSS").map { |bet| bet.stake * bet.odds }.sum
    @profit_loss = (profit - loss).round(2)
    @account_balance = ExchangeService.new.get_account_balance
    @bet_chart = {}
    bet_hours = Bet.all.map { |bet| bet.created_at.strftime("%Y/%m/%d %H") }.uniq
    total_profit_over_time = 0
    bet_hours.each do |bet_hour|
      won_bets_in_bet_hour = Bet.where("status='WIN' AND created_at > '#{bet_hour.gsub("/", "-")}:00:00 UTC' AND created_at < '#{bet_hour.gsub("/", "-")}:59:59 UTC'")
      lost_bets_in_bet_hour = Bet.where("status='LOSS' AND created_at > '#{bet_hour.gsub("/", "-")}:00:00 UTC' AND created_at < '#{bet_hour.gsub("/", "-")}:59:59 UTC'")
      lost_bets_in_bet_hour_sum = lost_bets_in_bet_hour.map { |bet| bet.stake * bet.odds }.sum
      total_profit_over_time = total_profit_over_time + won_bets_in_bet_hour.sum(:stake)
      total_profit_over_time = total_profit_over_time - lost_bets_in_bet_hour_sum
      @bet_chart[bet_hour] = total_profit_over_time
    end
  end
end