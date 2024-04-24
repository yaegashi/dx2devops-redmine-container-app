require 'redmine'

RedmineEasyauthViewListener

AccountController.send(:helper, RedmineEasyauthHelper)

Redmine::Plugin.register :redmine_easyauth do
  name 'Redmine Easy Auth plugin'
  author 'YAEGASHI Takeshi'
  description 'Authentication/registration plugin with Azure App Service Easy Auth'
  version '0.0.4'
  author_url 'https://github.com/yaegashi'

  settings default: {
    enabled: false,
    auto_registration: false,
    announcement: ''
  }, partial: 'settings/easyauth_settings'
end
