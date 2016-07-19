rails_env = ENV['RAILS_ENV']
app_root = ENV['RAILS_ROOT'] || "/var/www/apps/app1/current"
rake_root = ENV['RAKE_ROOT'] || "/home/myuser/.rvm/wrappers/ruby-2.0.0-p598"
name_prefix = "god-resque-app1-#{rails_env}"

num_workers = 1

num_workers.times do |num|
  God.watch do |w|
    w.uid = 'uadmin'
    w.gid = 'dev'

    w.name          = "#{name_prefix}-#{num}"
    w.group         = 'resque'

    w.env           = { 'RAILS_ENV' => rails_env, 'QUEUE' => '*' }
    w.dir           = app_root
    
    w.pid_file = File.join(app_root, "tmp/pids/", "#{w.name}.pid")    
    w.log           = File.join(app_root, 'log', "#{w.name}.log")


    w.start         = "#{rake_root}/rake resque:work"
    #w.stop = "..." 

    #
    w.keepalive
    w.behavior(:clean_pid_file)

    w.interval      = 90.seconds
    w.start_grace = 10.seconds
    w.restart_grace = 10.seconds    

    w.stop_signal = 'QUIT'
    w.stop_timeout = 20.seconds
  

   
    # restart if memory gets too high
    w.transition(:up, :restart) do |on|
      on.condition(:memory_usage) do |c|
        c.above = 200.megabytes
        c.times = 2
      end
    end

    # determine the state on startup
    w.transition(:init, { true => :up, false => :start }) do |on|
      on.condition(:process_running) do |c|
        c.running = true
      end
    end

    # determine when process has finished starting
    w.transition([:start, :restart], :up) do |on|
      on.condition(:process_running) do |c|
        c.running = true
        c.interval = 5.seconds
      end

      # failsafe
      on.condition(:tries) do |c|
        c.times = 5
        c.transition = :start
        c.interval = 5.seconds
      end
    end

    # start if process is not running
    w.transition(:up, :start) do |on|
      on.condition(:process_running) do |c|
        c.running = false
      end
    end


    # after touch tmp/restart.txt
    w.transition(:up, :restart) do |on|
      # restart if server is restarted
      on.condition(:file_touched) do |c|
        c.interval = 5.seconds
        c.path = File.join(rails_root, 'tmp', 'restart.txt')
      end
    end
    

  end
end    
