require 'redmine'

require_relative 'lib/redmine_sidekiq_route_constraint'

Redmine::Plugin.register :redmine_sidekiq do
  name 'Redmine Sidekiq plugin'
  author 'YAEGASHI Takeshi'
  description 'Redmine Sidekiq dashboard integration'
  version '0.0.1'

  menu :admin_menu, :sidekiq, '/sidekiq', :caption => 'Sidekiq Dashboard', html: { class: 'icon icon-plugins' }
end