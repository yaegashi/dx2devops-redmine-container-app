require 'json'

class RMOps::CLI
  desc 'env', 'Environment variable manipulation'
  def env(ops=nil, key=nil, val=nil)
    case ops
    when nil
      env = RMOps::Utils.env_load
      puts JSON.pretty_generate(env)
    when 'get'
      raise 'No key specified' if key.nil?
      puts RMOps::Utils.env_get(key)
    when 'set'
      raise 'No key specified' if key.nil?
      raise 'No val specified' if val.nil?
      RMOps::Utils.env_set(key, val)
    when 'unset'
      raise 'No key specified' if key.nil?
      RMOps::Utils.env_set(key, nil)
    else
      raise "Unknown operation: #{ops}"
    end
  rescue StandardError => e
    logger.fatal e.to_s
    exit 1
  end
end
