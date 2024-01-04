# frozen_string_literal: true

class RedmineSidekiqRouteConstraint
  def matches?(request)
    user_id = request.session[:user_id]
    return false unless user_id
    user = User.find(user_id)
    user && user.admin?
  end
end
