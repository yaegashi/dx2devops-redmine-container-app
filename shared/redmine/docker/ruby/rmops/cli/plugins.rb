require 'fileutils'

class RMOps::CLI
  desc 'plugins', 'Install public plugins'
  def plugins
    RMOps::Tasks.install_plugins
    RMOps::Tasks.create_symlinks
    RMOps::Tasks.bundle_install
    RMOps::Tasks.migrate_database
  rescue StandardError => e
    logger.fatal e.to_s
    exit 1
  end
end
