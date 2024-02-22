require 'logger'

module RMOps::Logger
  def self.included(base)
    base.extend self
  end

  def logger
    return @logger if defined?(@logger)
    unbuffered = STDOUT.clone
    unbuffered.sync = true
    @logger = Logger.new(unbuffered)
  end
end
