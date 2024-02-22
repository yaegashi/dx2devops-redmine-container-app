require 'fileutils'
require 'json'

module RMOps::Utils
  extend RMOps::Utils
  include RMOps::Consts
  include RMOps::Logger

  def pwgen(len = 16)
    s = [*('A'..'Z'), *('a'..'z'), *(0..9)]
    (0...len).map { s.sample }.join
  end

  def run(cmdline, opts = { exception: true })
    logger.info "Run #{cmdline.inspect}"
    system(cmdline, opts)
  end

  def symlink(src, dst, **opts)
    logger.info "Symlink #{src.inspect} to #{dst.inspect}"
    FileUtils.rmtree(File.join(dst, File.basename(src))) if opts[:force] && File.directory?(dst)
    FileUtils.symlink(src, dst, **opts)
  end

  def copytree(src, dst, **opts)
    logger.info "Copy #{src.inspect} to #{dst.inspect}"
    FileUtils.cp_r(src, dst, **opts)
  end

  def rmtree(list, **opts)
    logger.info "Remove #{list}"
    FileUtils.rmtree(list, **opts)
  end

  def makedirs(list, **opts)
    logger.info "Create #{list}"
    FileUtils.makedirs(list, **opts)
  end

  def enter_dir(dir = REDMINE_DIR, **opts, &block)
    logger.info "Enter directory at #{dir}" unless opts[:quiet]
    raise "#{dir} is not a directory" unless File.directory?(dir)

    Dir.chdir(dir, &block)
  end

  def enter_redmine(dir = REDMINE_DIR, **opts)
    logger.info "Enter Redmine at #{dir}" unless opts[:quiet]
    raise "#{dir} is not a Redmine" unless File.file?(File.join(dir, 'bin/rails'))

    Dir.chdir(dir) do
      require './config/environment'
      ActionMailer::Base.perform_deliveries = false
      yield
    end
  end

  def probe_server(server_url)
    require 'uri'
    require 'net/http'
    uri = URI.parse(server_url)
    Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https') do |http|
      http.request(Net::HTTP::Get.new(uri))
    end
    true
  rescue StandardError
    false
  end

  def env_load
    if File.exist?(ENV_JSON)
      JSON.parse(File.read(ENV_JSON))
    else
      {}
    end
  end

  def env_save(env)
    File.write(ENV_JSON, JSON.pretty_generate(env))
  end

  def env_get(key)
    env = env_load
    env[key]
  end

  def env_set(key, val)
    env = env_load
    if val.nil?
      env.delete(key)
    else
      env[key] = val
    end
    env_save(env)
  end
end
