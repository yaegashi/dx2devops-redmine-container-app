class RMOps::CLI
  desc 'sidekiq', 'Sidekiq container entrypoint'
  def sidekiq
    raise 'Not an entrypoint process (PID != 1)' if Process.pid != 1

    RMOps::Tasks.create_symlinks
    RMOps::Tasks.initialize_secret_key_base
    RMOps::Tasks.initialize_database_config
    RMOps::Tasks.migrate_database

    mode = RMOps::Utils.env_get('sidekiq')
    logger.info "Sidekiq operation mode: #{mode.inspect}"
    case mode
    when 'enable'
      RMOps::Tasks.start_sidekiq
    else
      RMOps::Tasks.start_sleep
    end
  rescue StandardError => e
    logger.fatal e.to_s
    RMOps::Tasks.start_sleep
    exit 1
  end
end
