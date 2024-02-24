require 'fileutils'

class RMOps::CLI
  desc 'plugins', 'Install public plugins (no migrations)'
  def plugins
    RMOps::Tasks.install_plugins
  rescue StandardError => e
    logger.fatal e.to_s
    exit 1
  end
end
