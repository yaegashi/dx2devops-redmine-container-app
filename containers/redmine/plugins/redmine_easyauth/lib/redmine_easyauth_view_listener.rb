class RedmineEasyauthViewListener < Redmine::Hook::ViewListener
  render_on :view_account_login_bottom, partial: 'easyauth/signin'
end
