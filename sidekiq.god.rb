rails_env = 'production'

# for RVM
rake_root = "/home/<MYUSER>/.rvm/wrappers/ruby-2.1.7"
bin_path   = "/home/<MYUSER>/.rvm/gems/ruby-2.1.7/bin/"

#
app_root = "/var/www/apps/app3/current"

name_prefix = "god-sidekiq-#{rails_env}"


num_workers = 1

num_workers.times do |num|
  
  
God.watch do |w|
    w.uid = 'myuser'
    w.gid = 'myuser'

    w.name          = "#{name_prefix}-#{num}"
    w.group         = 'sidekiq'
    w.env           = { 'RAILS_ENV' => rails_env, 'QUEUE' => '*' }
    w.dir           = app_root

    w.pid_file = File.join(app_root, "tmp/pids/", "#{w.name}.pid")
    w.log           = File.join(app_root, 'log', "#{w.name}.log")


    #
    w.start = "bundle exec sidekiq -e #{rails_env} -c 1 -C #{app_root}/config/sidekiq.yml -L #{w.log} -P #{w.pid_file}"
    w.stop  = "kill -TERM `cat #{w.pid_file}`"
    #w.stop  = "if [ -d #{app_root} ] && [ -f #{w.pid_file} ] && kill -0 `cat #{w.pid_file}`> /dev/null 2>&1; then cd #{app_root} && #{bin_path}/bundle exec sidekiqctl stop #{w.pid_file} 10 ; else echo 'Sidekiq is not running'; fi"


    #
    w.keepalive
    w.behavior(:clean_pid_file)

    w.interval      = 30.seconds
    w.start_grace = 10.seconds
    w.restart_grace = 10.seconds

    #w.stop_signal = 'QUIT'
    #w.stop_timeout = 20.seconds



    #
    w.start_if do |start|
      start.condition(:process_running) do |c|
        c.interval = 5.seconds
        c.running = false
      end
    end

    w.restart_if do |restart|
      restart.condition(:memory_usage) do |c|
        c.above = 300.megabytes
        c.times = [3, 5] # 3 out of 5 intervals
      end

      restart.condition(:cpu_usage) do |c|
        c.above = 50.percent
        c.times = 5
      end
    end

    w.lifecycle do |on|
      on.condition(:flapping) do |c|
        c.to_state = [:start, :restart]
        c.times = 5
        c.within = 5.minute
        c.transition = :unmonitored
        c.retry_in = 10.minutes
        c.retry_times = 5
        c.retry_within = 2.hours
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
