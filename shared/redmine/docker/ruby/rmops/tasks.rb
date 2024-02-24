require 'io/console'
require 'tmpdir'

module RMOps::Tasks
  extend RMOps::Tasks
  include RMOps::Consts
  include RMOps::Utils

  def self.create_symlinks
    enter_dir do
      rmtree(['files', 'public/plugin_assets'])
      makedirs([FILES_DIR, CONFIG_DIR, PLUGINS_DIR, PUBLIC_THEMES_DIR, PUBLIC_PLUGIN_ASSETS_DIR,
                ETC_DIR, STATICSITE_DIR, BACKUPS_DIR])
      symlink(FILES_DIR, './files', force: true)
      symlink(PUBLIC_PLUGIN_ASSETS_DIR, './public/plugin_assets', force: true)
      Dir.glob(File.join(PLUGINS_DIR, '*')).each do |path|
        symlink(path, 'plugins', force: true) if File.directory?(path)
      end
      Dir.glob(File.join(PUBLIC_THEMES_DIR, '*')).each do |path|
        symlink(path, 'public/themes', force: true) if File.directory?(path)
      end
      if File.exist?(CONFIG_LINK)
        Dir.glob(File.join(CONFIG_DIR, '*')).each do |path|
          next if path == CONFIG_LINK
          symlink(path, 'config', force: true) if File.file?(path)
        end
      end
    end
  end

  def bundle_install
    enter_dir do
      run 'bundle install'
    end
  end

  def install_plugin(url, branch=nil, dir=nil)
    dir = File.basename(url) if dir.nil?
    if File.directory?(dir)
      run "git -C #{dir} remote update"
      if branch
        run "git -C #{dir} checkout -q #{branch}"
      else
        run "git -C #{dir} pull -q"
      end
    else
      run "git clone -q --filter=blob:none #{url} #{dir}"
      run "git -C #{dir} checkout -q #{branch}" if branch
    end
  end

  def install_plugins
    Dir.chdir(PLUGINS_DIR) do
      install_plugin 'https://github.com/agileware-jp/redmine_issue_templates', 'v1.1.2'
      install_plugin 'https://github.com/farend/redmine_message_customize', 'v1.0.0'
      install_plugin 'https://github.com/onozaty/redmine-view-customize', 'v3.5.1', 'view_customize'
      install_plugin 'https://github.com/redmica/redmica_ui_extension', 'v0.3.5'
      install_plugin 'https://github.com/redmica/redmine_ip_filter', 'v0.0.2'
      install_plugin 'https://github.com/redmica/redmine_issues_panel', 'v0.0.7'
      install_plugin 'https://github.com/vividtone/redmine_vividtone_my_page_blocks', '1.2', 'redmine_vividtone_mypage_blocks'
    end
  end

  def migrate_database
    enter_dir do
      run 'rake db:migrate'
      run 'rake redmine:plugins:migrate'
    end
  end

  def default_admin_account_changed?
    enter_redmine(quiet: true) do
      User.default_admin_account_changed?
    end
  end

  def reset_passwd(login)
    enter_redmine do
      u = User.find_by(login: login)
      raise "User not found: #{login}" if u.nil?

      pass = pwgen
      u.password = pass
      u.password_confirmation = pass
      u.must_change_passwd = true
      u.save!

      File.open(RMOps::Consts::PASSWORD_TXT, 'a') do |f|
        f.puts "#{Time.now.strftime('%FT%T%:z')} #{login} #{pass}"
      end

      pass
    end
  end

  def initialize_secret_key_base
    enter_dir do
      if ENV['SECRET_KEY_BASE'].nil?
        logger.warn 'Initialize SECRET_KEY_BASE variable'
        require 'securerandom'
        ENV['SECRET_KEY_BASE'] = SecureRandom.hex(64)
      end
    end
  end

  def initialize_database_config
    logger.info 'Initialize config/database.yml'
    enter_dir do
      if DATABASE_URL and !File.exist?('config/database.yml')
        dburl = RMOps::DatabaseURL.new(DATABASE_URL)
        File.open('config/database.yml', 'w') do |file|
          file.puts %({"0":{"adapter":"#{dburl.db.type}"}})
        end
      end
    end
  end

  def start_openssh_server
    logger.info 'Initialize /root/.ssh/environment'
    Dir.mkdir('/root/.ssh', 0o700) unless File.exist?('/root/.ssh')
    File.open('/root/.ssh/environment', 'w') do |file|
      ENV.each do |k, v|
        file.puts "#{k}=#{v}"
      end
    end
    logger.info 'Start OpenSSH server'
    run '/usr/sbin/sshd'
  rescue StandardError => e
    logger.error e.to_s
    logger.warn 'Skip OpenSSH server'
  end

  def start_standby_server(port = 8080)
    logger.info 'Starting standby server'
    pid = fork do
      require 'webrick'
      require 'stringio'
      s = WEBrick::HTTPServer.new(Port: port)
      s.mount_proc('/') do |req, res|
        res.status = 503
        res['Content-Type'] = 'text/html'
        res['Retry-After'] = '10'
        res.body = StringIO.new
        res.body.puts <<-HTML
        <!DOCTYPE html>
        <html>
        <head><meta http-equiv="refresh" content="10"></head>
        <body><p>Starting service, please wait...</p></body>
        </html>
        HTML
        res.body.rewind
      end
      trap('TERM') { s.shutdown }
      s.start
    end
    if block_given?
      begin
        yield
      ensure
        Process.kill('TERM', pid)
        Process.wait(pid)
      end
    else
      pid
    end
  end

  def start_rails_server
    logger.info 'Starting rails server'
    enter_dir do
      File.unlink('tmp/pids/server.pid') if File.exist?('tmp/pids/server.pid')
      run 'rails server -b 0.0.0.0 -p 8080'
    end
  end

  def start_debug_server
    logger.info 'Starting debug server'
    require 'webrick'
    require 'stringio'
    s = WEBrick::HTTPServer.new(Port: 8080)
    s.mount_proc('/') do |req, res|
      res.status = 200
      res['Content-Type'] = 'text/plain'
      res.body = StringIO.new
      res.body.puts "self: #{req.addr.inspect}"
      res.body.puts "peer: #{req.peeraddr.inspect}"
      res.body.puts "#{req.request_method} #{req.unparsed_uri}"
      res.body.puts req.raw_header.join
      res.body.rewind
    end
    s.start
  end

  def start_staticsite_server
    logger.info 'Starting static site server'
    index_file = File.join(STATICSITE_DIR, 'index.html')
    unless File.exist?(index_file)
      File.open(index_file, 'w') do |file|
        file.puts 'Maintenance mode'
      end
    end
    require 'webrick'
    s = WEBrick::HTTPServer.new(Port:8080, DocumentRoot: STATICSITE_DIR)
    s.start
  end

  def start_sidekiq
    logger.info 'Starting sidekiq'
    enter_dir do
      run 'sidekiq'
    end
  end

  def start_sleep
    logger.info 'Sleeping forever'
    loop do
      sleep 86400
    end
  end

  def dbinit(url, adminuser, adminpass)
    userurl = RMOps::DatabaseURL.new(url)
    sql = userurl.generate_dbsql
    adminurl = RMOps::DatabaseURL.new(url, user: adminuser, pass: adminpass)
    args = adminurl.generate_cliadmin

    logger.info 'Create database'
    logger.info "Run #{args.inspect}"
    IO.popen(adminurl.env, args, 'w', exception: true) do |io|
      io.print(sql)
    end

    raise 'Failed database initialization' unless $?.success?

    logger.info 'Done database initialization'
  end

  def dbcli(url)
    userurl = RMOps::DatabaseURL.new(url)
    args = userurl.generate_cliuser
    logger.info "Run #{args.inspect}"
    system(userurl.env, *args, exception: true)
  end

  def symlink_directory(srcdir, tmpdir)
    dstdir = File.join(tmpdir, File.basename(srcdir))
    if File.directory?(srcdir)
      symlink(srcdir, dstdir)
    end
  end

  def dump(name)
    name += '.tgz' unless name.end_with?('.tar.gz', '.tgz')
    tgzpath = File.expand_path(name, BACKUPS_DIR)

    Dir.mktmpdir do |dir|
      dbdump = File.join(dir, 'db.dump')
      dburl = RMOps::DatabaseURL.new(DATABASE_URL)
      args = dburl.generate_dump
      logger.info "Dump database to #{dbdump}"
      logger.info "Run #{args.inspect}"
      system(dburl.env, *args, exception: true, out: dbdump)
      symlink_directory(ETC_DIR, dir)
      symlink_directory(STATICSITE_DIR, dir)
      symlink_directory(FILES_DIR, dir)
      symlink_directory(CONFIG_DIR, dir)
      symlink_directory(PLUGINS_DIR, dir)
      symlink_directory(PUBLIC_DIR, dir)
      run "tar -C #{dir} -f #{tgzpath} -czvvh --owner root --group root --mode a+rX,og-w ."
      logger.info "Done dump to #{tgzpath}"
    end
  end

  def restore_directory(tmpdir, dstdir)
    srcdir = File.join(tmpdir, File.basename(dstdir))
    if File.directory?(srcdir)
      rmtree([dstdir])
      copytree(srcdir, dstdir)
    end
  end

  def restore(name)
    name += '.tgz' unless name.end_with?('.tar.gz', '.tgz')
    tgzpath = File.expand_path(name, BACKUPS_DIR)
    raise "Backup not found: #{name}" unless File.exist? tgzpath

    Dir.mktmpdir do |dir|
      run "tar -C #{dir} -f #{tgzpath} -xzvv --no-same-owner --no-same-permissions"
      restore_directory(dir, ETC_DIR)
      restore_directory(dir, STATICSITE_DIR)
      restore_directory(dir, FILES_DIR)
      restore_directory(dir, CONFIG_DIR)
      restore_directory(dir, PLUGINS_DIR)
      restore_directory(dir, PUBLIC_DIR)
      dbdump = File.join(dir, 'db.dump')
      dburl = RMOps::DatabaseURL.new(DATABASE_URL)
      args = dburl.generate_restore

      # Modify the database dump before restore
      File.open(dbdump, 'r+') do |file|
        sql = file.read
        case dburl.db.type
        when 'mysql2'
          # Comment out variable settings to prevent "Access denied" error
          sql.gsub!(/^SET @@SESSION.SQL_LOG_BIN=/, '-- \&')
          sql.gsub!(/^SET @@GLOBAL.GTID_PURGED=/, '-- \&')
        end
        file.rewind
        file.write(sql)
      end

      logger.info "Restore database from #{dbdump}"
      logger.info "Run #{args.inspect}"
      system(dburl.env, *args, exception: true, in: dbdump)
      logger.info "Done restore from #{tgzpath}"
    end
  end
end
