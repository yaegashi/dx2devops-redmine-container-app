class RMOps::CLI
  desc 'passwd', 'Reset user password'
  def passwd(login)
    RMOps::Tasks.create_symlinks
    RMOps::Tasks.initialize_database_config
    RMOps::Tasks.bundle_install
    RMOps::Tasks.reset_passwd(login)
    logger.info "Reset password for user #{login.inspect}"
    logger.info "The password was written in password.txt"
    logger.info "Command to show the password: tail -1 #{RMOps::Consts::PASSWORD_TXT}"
  rescue StandardError => e
    logger.fatal e.to_s
    exit 1
  end
end
