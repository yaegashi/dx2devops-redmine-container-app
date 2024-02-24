require 'thor'

class RMOps::CLI < Thor
  include RMOps::Consts
  include RMOps::Logger

  def self.exit_on_failure?
    true
  end
end

require_relative 'cli/dbcli'
require_relative 'cli/dbinit'
require_relative 'cli/dbsql'
require_relative 'cli/dump'
require_relative 'cli/env'
require_relative 'cli/install'
require_relative 'cli/passwd'
require_relative 'cli/plugins'
require_relative 'cli/rails'
require_relative 'cli/restore'
require_relative 'cli/setup'
require_relative 'cli/sidekiq'
require_relative 'cli/symlinks'
