namespace 'srodgers' do
  task :check_bets => :environment do
    exchange_settled_bets = ExchangeService.new.get_settled_bets_report
    if exchange_settled_bets["markets"].any?
      exchange_settled_bets["markets"].each do |market|
        market["selections"].each do |selection|
          selection["bets"].each do |bet|
            offer_id = bet["offer-id"]
            result = bet["result"]
            if offer_id && result
              bet = Bet.find_by(offer_id: offer_id)
              if bet
                bet.update_attribute(:status, result)
                bet.save

                if result == "LOSS"
                  AlertsMailer.bet_lost(bet).deliver_now
                end
              end
            end
          end
        end
      end
    end
  end
end