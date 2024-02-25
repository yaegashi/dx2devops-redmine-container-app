class RMOps::CLI
  desc 'sidekiq', 'Sidekiq container entrypoint'
  def sidekiq
    raise 'Not an entrypoint process (PID != 1)' if Process.pid != 1

    RMOps::Tasks.create_symlinks

    mode = RMOps::Utils.env_get('sidekiq')
    logger.info "Sidekiq operation mode: #{mode.inspect}"
    case mode
    when 'enable'
      loop do
        logger.info "Probing rails server at #{REDMINE_CONTAINER_URL}"
        break if RMOps::Utils.probe_server(REDMINE_CONTAINER_URL)
        sleep 10
      end
      RMOps::Tasks.initialize_database_config
      RMOps::Tasks.bundle_install
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
