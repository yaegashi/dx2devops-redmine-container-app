# https://www.redmine.org/projects/redmine/wiki/HowTo_Install_Redmine_in_a_sub-URI#With-puma

require_relative 'config/environment'

root = ENV['RAILS_RELATIVE_URL_ROOT'] || '/'

map root do
  run Rails.application
end

if root != '/'
  redirector = Proc.new { [301, { Location: root }, []] }
  map '/' do
    run redirector
  end
end
