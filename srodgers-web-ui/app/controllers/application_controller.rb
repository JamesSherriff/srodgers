class ApplicationController < ActionController::Base
  http_basic_authenticate_with name: Rails.application.credentials.login_name, password: Rails.application.credentials.login_password
end
