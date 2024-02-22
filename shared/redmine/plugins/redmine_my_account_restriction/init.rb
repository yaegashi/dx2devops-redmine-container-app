require 'redmine'

Redmine::Plugin.register :redmine_my_account_restriction do
  name 'Redmine My Account Restriction plugin'
  author 'YAEGASHI Takeshi'
  description 'Restrict users from updating their own information and preferences'
  version '0.0.1'
  author_url 'https://github.com/yaegashi'
end

Rails.configuration.after_initialize do
  MyController.send :include, MyAccountRestrictionPatch
end
