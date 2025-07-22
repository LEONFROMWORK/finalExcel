# spec/support/request_helpers.rb
module RequestHelpers
  def json_response
    JSON.parse(response.body, symbolize_names: true)
  end

  def auth_headers(user)
    {
      'Authorization' => "Bearer #{generate_jwt_for(user)}",
      'Content-Type' => 'application/json'
    }
  end

  def generate_jwt_for(user)
    JWT.encode(
      { user_id: user.id, exp: 1.hour.from_now.to_i },
      Rails.application.credentials.secret_key_base
    )
  end
end

RSpec.configure do |config|
  config.include RequestHelpers, type: :request
end
