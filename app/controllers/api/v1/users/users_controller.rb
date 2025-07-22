module Api
  module V1
    module Users
      class UsersController < Api::V1::ApiController
        # Authentication is handled by parent controller

        # GET /api/v1/users/current
        def current
          render json: UserSerializer.new(current_user).as_json
        end

        # PATCH /api/v1/users/credits
        def update_credits
          amount = params[:amount].to_i

          if amount == 0
            render json: { error: "Invalid amount" }, status: :bad_request
            return
          end

          new_credits = current_user.credits + amount

          if new_credits < 0
            render json: { error: "Insufficient credits" }, status: :bad_request
            return
          end

          current_user.update!(credits: new_credits)

          render json: {
            credits: current_user.credits,
            message: amount > 0 ? "Credits added" : "Credits deducted"
          }
        end

        # POST /api/v1/users/purchase-credits
        def purchase_credits
          plan = params[:plan]

          # Define credit plans
          plans = {
            "basic" => { credits: 100, price: 1000 },
            "standard" => { credits: 300, price: 2500 },
            "premium" => { credits: 1000, price: 7500 },
            "enterprise" => { credits: 5000, price: 30000 }
          }

          selected_plan = plans[plan]

          unless selected_plan
            render json: { error: "Invalid plan" }, status: :bad_request
            return
          end

          # In production, integrate with payment gateway here
          # For now, just add credits
          current_user.update!(credits: current_user.credits + selected_plan[:credits])

          render json: {
            credits: current_user.credits,
            purchased: selected_plan[:credits],
            message: "Successfully purchased #{selected_plan[:credits]} credits"
          }
        end
      end
    end
  end
end
