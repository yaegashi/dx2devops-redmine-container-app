require 'fileutils'

class RMOps::CLI
  desc 'install', 'Run bundle install'
  def install
    RMOps::Tasks.create_symlinks
    RMOps::Tasks.initialize_database_config
    RMOps::Tasks.bundle_install
  rescue StandardError => e
    logger.fatal e.to_s
    exit 1
  end
end
