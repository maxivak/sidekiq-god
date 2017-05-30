rails_env = 'production'

# for RVM
rake_root = "/home/<MYUSER>/.rvm/wrappers/ruby-2.3.3"
bin_path   = "/home/<MYUSER>/.rvm/gems/ruby-2.3.3/bin/"

#
app_root = "/var/www/apps/app3/current"

name_prefix = "god-sidekiq-#{rails_env}"

# settings
stop_timeout = 1800
concurrency = 10 

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
    sidekiq_options = "-e #{rails_env} -t #{stop_timeout}  -c #{concurrency} -C #{app_root}/config/sidekiq.yml -L #{w.log} -P #{w.pid_file}"
    w.start = "cd #{app_root}; nohup #{bin_path}/bundle exec sidekiq -d  #{sidekiq_options} 2>&1 &"
    w.stop  = "cd #{app_root} && sidekiqctl stop #{w.pid_file} #{stop_timeout} "
   
  #w.stop  = "kill -TERM `cat #{w.pid_file}`"
  #w.stop  = "if [ -d #{app_root} ] && [ -f #{w.pid_file} ] && kill -0 `cat #{w.pid_file}`> /dev/null 2>&1; then cd #{app_root} && #{bin_path}/bundle exec sidekiqctl stop #{w.pid_file} 10 ; else echo 'Sidekiq is not running'; fi"


    #
    w.keepalive
    w.behavior(:clean_pid_file)
  
    #
    w.interval      = 30.seconds

    w.start_grace = 20.seconds
    w.restart_grace = 20.seconds

    #w.stop_signal = 'QUIT'
    w.stop_timeout = stop_timeout.seconds




# from godrb.com
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




=begin
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
=end
  
  

  ### restart  after touch tmp/restart.txt
      w.restart_if do |on|
        on.condition(:file_touched) do |c|
          c.interval = 5.seconds
          c.path = File.join(app_root, 'tmp', 'restart.txt')
        end

      end
  
  

  end
end
