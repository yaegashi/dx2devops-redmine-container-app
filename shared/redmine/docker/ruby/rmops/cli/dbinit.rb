class RMOps::CLI
  desc 'dbinit', 'Initialize database'
  def dbinit(adminuser=nil, adminpass=nil)
    if adminuser.nil?
      print 'Enter DB admin username: '
      adminuser = STDIN.gets.chomp
    end
    if adminpass.nil?
      print 'Enter DB admin password: '
      adminpass = STDIN.noecho(&:gets).chomp
      puts
    end
    RMOps::Tasks.dbinit(DATABASE_URL, adminuser, adminpass)
  rescue StandardError => e
    logger.fatal e.to_s
    exit 1
  end
end
