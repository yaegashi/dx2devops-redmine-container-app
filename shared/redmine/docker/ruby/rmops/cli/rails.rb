class RMOps::CLI
  desc 'rails', 'Rails container entrypoint'
  def rails
    raise 'Not an entrypoint process (PID != 1)' if Process.pid != 1

    RMOps::Tasks.create_symlinks

    mode = RMOps::Utils.env_get('rails')
    logger.info "Rails operation mode: #{mode.inspect}"
    case mode
    when 'enable'
      RMOps::Tasks.initialize_secret_key_base
      RMOps::Tasks.initialize_database_config
      RMOps::Tasks.bundle_install
      RMOps::Tasks.migrate_database
      RMOps::Tasks.start_rails_server
    when 'debug'
      RMOps::Tasks.start_debug_server
    else
      RMOps::Tasks.start_staticsite_server
    end
  rescue StandardError => e
    logger.fatal e.to_s
    RMOps::Tasks.start_staticsite_server
    exit 1
  end

  map 'entrypoint' => :rails
end
