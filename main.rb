require 'uri'
require 'net/http'
require 'date'
require 'json'
require 'sqlite3'

$exchange_api_base_url = "https://api.matchbook.com"
$exchange_username = "jamesyoui"
$exchange_password = "C0nverse!"

$previous_check_time = DateTime.now - Rational(1800, 86400)
$last_auth_token_refresh_datetime = nil

$sport_id = "24735152712200"

$target_liability = 10.to_f
$target_liability_flex = 1.to_f
$min_stake = 0.1.to_f

$db = SQLite3::Database.new('srodgers.db')

# Main method
def tick
	check_account_balance_and_update_target_liability
	check_for_and_place_bets
	check_open_bets
end

def auth_token(refresh = false)
	if refresh || $last_auth_token_refresh_datetime.nil? || $last_auth_token_refresh_datetime < (DateTime.now - Rational(18000, 86400))
		credentials = {
			"username": $exchange_username,
			"password": $exchange_password
		}
		auth_response = make_exchange_request("/bpapi/rest/security/session", :post, credentials.to_json, true)
		new_auth_token = auth_response["session-token"]
		@auth_token ||= new_auth_token
		$last_auth_token_refresh_datetime = DateTime.now
	end
	@auth_token
end

def check_account_balance_and_update_target_liability
	account_balance_response = make_exchange_request("/edge/rest/account/balance")
	balance = account_balance_response["balance"]
	$target_liability = balance / 10
end

def check_for_and_place_bets
	bets_placed = 0
	events = get_current_events
	events.each do |event|
		bettable_market = get_bettable_market_in_event(event)

		if bettable_market
			event_id = event["id"]
			market_id =	bettable_market["id"]
			runner_id, odds = get_best_runner_from_market(bettable_market)
			stake = calculate_stake(odds)

			if runner_id && odds && stake && (bets_placed < 1) && stake > $min_stake
				bet_already_placed = $db.execute("SELECT runner_id FROM bets WHERE runner_id = '#{runner_id}' AND market_id = '#{market_id}'").any?
				place_bet(event_id, market_id, runner_id, odds, stake) unless bet_already_placed
				bets_placed = (bets_placed + 1) unless bet_already_placed
			end
		end
	end
end

def check_open_bets
	exchange_settled_bets_response = make_exchange_request("/edge/rest/reports/v2/bets/settled")
	if exchange_settled_bets_response["markets"].any?
		exchange_settled_bets_response["markets"].each do |market|
			market["selections"].each do |selection|
				selection["bets"].each do |bet|
					current_bet_status = $db.execute("SELECT status FROM bets WHERE offer_id=#{bet["offer-id"].to_i}")
					puts "Bet status update - Offer ID: #{bet["offer-id"]} New Status: #{bet["result"]}"
					$db.execute("UPDATE bets SET status='#{bet["result"]}' WHERE offer_id=#{bet["offer-id"].to_i}")
				end
			end
		end
	end
end

def get_current_events
	make_exchange_request("/edge/rest/events?sport-ids=#{$sport_id}&per-page=50")["events"] # TODO: Do pagination here so we actually get all not just first 20
end

def place_bet(market_id, event_id, runner_id, odds, stake)
	bet_request_body = {
		"exchange-type": "back-lay",
		"odds-type": "DECIMAL",
		"offers": {
			"runner-id": runner_id,
			"side": "lay",
			"odds": odds,
			"stake": stake,
			"keep-in-play": true
		}
	}
	bet_response = make_exchange_request("/edge/rest/v2/offers", :post, bet_request_body.to_json)

	if bet_response["offers"].any?
		odds = bet_response["offers"][0]["odds"]
		stake = bet_response["offers"][0]["stake"]
		puts "Placed bet - Runner: #{runner_id}, Odds: #{odds}, Stake: #{stake}"
		offer_id = bet_response["offers"][0]["id"]
		$db.execute("INSERT INTO bets (market_id, event_id, runner_id, odds, stake, offer_id, status) VALUES ('#{event_id}', '#{market_id}', '#{runner_id}', #{odds}, #{stake}, '#{offer_id}', 'OPEN')")
	end
end

def calculate_stake(odds)
	odds = odds.to_f
	stake = $target_liability / odds
	if stake < $min_stake
		flex = $target_liability_flex / 10
		flex_stake = stake
		while flex < $target_liability_flex
			flex_stake = ($target_liability + $target_liability_flex) / odds
			flex = flex + ($target_liability_flex / 10)
		end
		stake = flex_stake
	end
	return stake
end

def get_bettable_market_in_event(event)
	event["markets"].each do |market|
		if market["name"].downcase == "win"
			runner_id, odds = get_best_runner_from_market(market)
			puts odds.inspect
			if odds > 60.to_i
				return market
			end
		end
	end
	return nil
end

def get_best_runner_from_market(market)
	best_runner = { runner_id: nil, odds: 0}
	market["runners"].each do |runner|
		current_runner_highest_odds = 0
		runner["prices"].each do |price|
			current_runner_highest_odds = price["odds"] if (price["side"] == "lay" && price["odds"] > current_runner_highest_odds)
		end
		best_runner = { odds: current_runner_highest_odds, runner_id: runner["id"] } if (best_runner[:odds] < current_runner_highest_odds)
	end
	return best_runner[:runner_id], best_runner[:odds]
end

def make_exchange_request(path, method = :get, body = nil, no_auth = false)
	url = URI($exchange_api_base_url + path)

	http = Net::HTTP.new(url.host, url.port)
	http.use_ssl = true

	if method == :get
		request = Net::HTTP::Get.new(url)
	elsif method == :post
		request = Net::HTTP::Post.new(url)
		request["content-type"] = "application/json"
		request.body = body unless body.nil?
	end
	request["User-Agent"] = "PostmanRuntime/7.36.3"
	request["accept"] = 'application/json'
	request["session-token"] = auth_token unless no_auth

	response = http.request(request)
	return JSON.parse(response.body)
end

while true do # TODO: Enable this
	if $previous_check_time && $previous_check_time < (DateTime.now - Rational(1800, 86400))
		tick
		$previous_check_time = DateTime.now
	end
end