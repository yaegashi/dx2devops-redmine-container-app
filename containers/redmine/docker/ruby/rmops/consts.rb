module RMOps::Consts
  def self.make_bool(str)
    case str.to_s.strip.downcase
    when 'true', 'yes', 'on', 't', 'y', '1'
      true
    else
      false
    end
  end

  REDMINE_DIR = ENV['REDMINE_DIR'] || '/redmine'
  WWWROOT_DIR = ENV['WWWROOT_DIR'] || '/home/site/wwwroot'
  ETC_DIR = File.join(WWWROOT_DIR, 'etc')
  ENV_JSON = File.join(ETC_DIR, 'env.json')
  PASSWORD_TXT = File.join(ETC_DIR, 'password.txt')
  STATICSITE_DIR = File.join(WWWROOT_DIR, 'staticsite')
  BACKUPS_DIR = File.join(WWWROOT_DIR, 'backups')
  FILES_DIR = File.join(WWWROOT_DIR, 'files')
  CONFIG_DIR = File.join(WWWROOT_DIR, 'config')
  CONFIG_LINK = File.join(CONFIG_DIR, '.LINK')
  PLUGINS_DIR = File.join(WWWROOT_DIR, 'plugins')
  PUBLIC_DIR = File.join(WWWROOT_DIR, 'public')
  PUBLIC_THEMES_DIR = File.join(WWWROOT_DIR, 'public/themes')
  PUBLIC_PLUGIN_ASSETS_DIR = File.join(WWWROOT_DIR, 'public/plugin_assets')
  DATABASE_URL = ENV['DATABASE_URL']
  DATABASE_SINGLE = make_bool(ENV['DATABASE_SINGLE'])
  REDMINE_CONTAINER_URL = ENV['REDMINE_CONTAINER_URL'] || 'http://localhost:8080'
end
