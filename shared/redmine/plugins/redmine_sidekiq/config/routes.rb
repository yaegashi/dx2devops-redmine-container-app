# frozen_string_literal: true

require 'sidekiq/web'

Rails.application.routes.draw do
  mount Sidekiq::Web => '/sidekiq', constraints: RedmineSidekiqRouteConstraint.new
end
