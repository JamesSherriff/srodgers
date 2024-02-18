class AlertsMailer < ApplicationMailer
  def bet_lost(bet)
    @bet = bet
    mail(to: Rails.application.credentials.alert_recipients, content_type: 'text/html', subject: 'Srodger Alert - Bet Failed')
  end
end
