require 'fileutils'

class RMOps::CLI
  desc 'symlinks', 'Create symlinks'
  def symlinks
    RMOps::Tasks.create_symlinks
  rescue StandardError => e
    logger.fatal e.to_s
    exit 1
  end
end
