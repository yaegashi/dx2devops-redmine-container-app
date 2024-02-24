require 'fileutils'

class RMOps::CLI
  desc 'setup', "Set up Redmine instance"
  def setup
    RMOps::Tasks.create_symlinks
    RMOps::Tasks.initialize_database_config
    RMOps::Tasks.bundle_install
    RMOps::Tasks.migrate_database
    unless RMOps::Tasks.default_admin_account_changed?
      login = 'admin'
      RMOps::Tasks.reset_passwd(login)
      logger.info "Reset password for user #{login.inspect}"
      logger.info "The password was written in password.txt"
      logger.info "Command to show the password: tail -1 #{RMOps::Consts::PASSWORD_TXT}"
    end
  rescue StandardError => e
    logger.fatal e.to_s
    exit 1
  end
end
