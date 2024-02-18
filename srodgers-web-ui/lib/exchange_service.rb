require 'net/http'
class ExchangeService
  def get_account_balance
    account_balance_response = make_exchange_request("/edge/rest/account/balance")
    return account_balance_response["balance"]
  end

  def get_settled_bets_report
    make_exchange_request("/edge/rest/reports/v2/bets/settled")
  end

  private
  def make_exchange_request(path, method = :get, body = nil, no_auth = false)
    url = URI("https://api.matchbook.com" + path)

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

  def auth_token(refresh = false)
    credentials = {
      "username": Rails.application.credentials.exchange_username,
      "password": Rails.application.credentials.exchange_password
    }
    auth_response = make_exchange_request("/bpapi/rest/security/session", :post, credentials.to_json, true)
    new_auth_token = auth_response["session-token"]
    @auth_token ||= new_auth_token
    @auth_token
  end
end