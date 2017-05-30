# God + Resque or Sidekiq
This post shows how to use God with Resque or Sidekiq with multiple Rails applications. 

It assumes that your already installed [Redis](https://github.com/redis/redis-rb) in your Rails applications.

[God](http://godrb.com/) is an easy to configure, easy to extend monitoring framework written in Ruby.

[Resque](https://github.com/resque/resque) is a Redis-backed library for creating background jobs, placing those jobs on multiple queues, and processing them later.

[Sidekiq](https://github.com/mperham/sidekiq) is background processing for Ruby. Sidekiq is compatible with Resque.




# God

## install gem
```ruby
gem install god
```

## God startup script

create wrapper for god:
```ruby
rvm wrapper ruby-2.3.3 boot god

```

create a startup script for god, so that god runs automatically after system boots.

file '/etc/init.d/god'
```ruby

CONF_FILE=/opt/god/master.conf
DAEMON=/home/myuser/.rvm/bin/boot_god # CHANGE it from - which boot_god
PIDFILE=/var/run/god.pid
LOGFILE=/var/log/god.log
SCRIPTNAME=/etc/init.d/god

#DEBUG_OPTIONS="--log-level debug"
DEBUG_OPTIONS=""


...

```
Find the whole file with the script in this gist.


create an empty log file:
```bash
touch /var/log/god.log
```

set execute permissions for the script:
```bash
sudo chmod +x /etc/init.d/god
```

make the script run automically
```bash
sudo chkconfig god on
or
sudo update-rc.d god defaults
```


config file for god:
/opt/god/master.conf:
```ruby

load "/opt/god/file_touched.rb"

# app1
load "/var/www/apps/app1/current/config/god/resque.god.rb"

# app2
load "/var/www/apps/app2/current/config/god/resque.god.rb"

# app3 with sidekiq
load "/var/www/apps/app2/current/config/god/sidekiq.god.rb"

```

This will watch resque tasks from multiple applications.

create file used for restarting tasks - /opt/god/file_touched.rb. Find the file in this gist.


## start god

to start god:
```bash
sudo service god start
```
Start god service after you set up your applications.


to restart god:
```bash
sudo service god restart
```


# Watching processes with God

watching daemonized processes:
* If the process you're watching runs as a daemon, you'll need to set the pid_file attribute.

watching non-daemonized processes:
* a script that doesn't have built in daemonization. God will daemonize and keep track of your process.
* If you don't specify a pid_file attribute for a watch, it will be auto-daemonized and a PID file will be stored for it in /var/run/god.


# Resque

## setup Resque in Rails application

Gemfile
```ruby
gem "resque"
```

### Redis namespace

Use Resque.redis.namespace config value for Resque to set different namespaces for applications.

initializer for Resque
config/initializers/resque.rb
```ruby
Resque.redis.namespace = 'resque_app1' # and 'resque_app2' for app2

```
! IMPORTANT ! set different namespaces for your applications.


### rake task for Resque

create rake task
lib/tasks/resque.rake
```ruby
require 'resque/tasks'

task "resque:setup" => :environment do
    ENV['QUEUE'] = "*"
end


```

### run Resque workers

you can run Resque to run all jobs:
```bash
rake resque:work
```

! IMPORTANT ! We don't need to run this command, because God will do this for us.


# Resque config for God

config/god/resque.god.rb

```ruby
rails_env = ENV['RAILS_ENV']
app_root = ENV['RAILS_ROOT'] || "/var/www/apps/app1/current"
rake_root = ENV['RAKE_ROOT'] || "/home/myuser/.rvm/wrappers/ruby-2.0.0-p598"
name_prefix = "god-resque-app1-#{rails_env}"

num_workers = 1

num_workers.times do |num|
  God.watch do |w|
    w.uid = 'myuser'
    w.gid = 'dev'

    w.name          = "#{name}-#{num}"
    w.group         = 'resque'
    w.env           = { 'RAILS_ENV' => rails_env, 'QUEUE' => '*' }
    w.dir           = app_root

    w.pid_file = File.join(app_root, "tmp/pids", "#{w.name}.pid")
    w.log           = File.join(app_root, 'log', "#{w.name}.log')

    #
    w.start         = "#{rake_root}/rake resque:work"

    #
    w.keepalive
    w.behavior(:clean_pid_file)

   

  end
end
```
Find the whole file below in this gist.



Use different values for app2:
```ruby
rails_env = ENV['RAILS_ENV']
app_root = ENV['RAILS_ROOT'] || "/var/www/apps/app2/current"
rake_root = ENV['RAKE_ROOT'] || "/home/myuser/.rvm/wrappers/ruby-2.0.0-p598"
name_prefix = "god-resque-app2-#{rails_env}"

num_workers = 1

# below is the same as for app1
...

```

# Sidekiq

install sidekiq:

Gemfile:
```
gem 'sidekiq'
```


config/sidekiq.yml

```
---
:concurrency: 1
:queues:
  - default
  - mailers
  
```


### Redis namespace


Use different Redis namespaces for different applictions


initializer for Resque
config/initializers/sidekiq.rb
```ruby
Sidekiq.configure_server do |config|
  config.redis = { url: 'redis://localhost:6379/0', namespace: "app3_sidekiq_#{Rails.env}" }
end

Sidekiq.configure_client do |config|
  config.redis = { url: 'redis://localhost:6379/0', namespace: "app3_sidekiq_#{Rails.env}" }
end


```
! IMPORTANT ! set different namespaces for your applications.



### run Sidekiq workers

You can start Sidekiq to run all jobs:
```bash
# run from the app root folder

# default
bundle exec sidekiq

# with options
bundle exec sidekiq -e production -c 1 -C config/sidekiq.yml -L /var/www/apps/app3/current/log/sidekiq.log

```

! IMPORTANT ! We don't need to run this command, because God will do this for us.


# Sidekiq config for God


config/god/sidekiq.god.rb

```ruby
rails_env = 'production'

rake_root = "/home/myuser/.rvm/wrappers/ruby-2.1.7"
bin_path   = "/home/myuser/.rvm/gems/ruby-2.3.3/bin"


app_root = "/var/www/apps/app3/current"
app_shared   = "/var/www/apps/app3/shared"


name_prefix = "god-sidekiq-#{rails_env}"

stop_timeout = 60
concurrency = 10

#
num_workers = 1

num_workers.times do |num|
  God.watch do |w|
    w.uid = 'myuser'
    w.gid = 'myuser'

    
    w.name = "#{name_prefix}-#{num}"
    w.group         = 'sidekiq'
    w.env           = { 'RAILS_ENV' => rails_env, 'QUEUE' => '*' }
    w.dir           = rails_root

    # pid file is important! because sidekiq will be running as daemonized process
    w.pid_file = File.join(app_root, "tmp/pids/", "#{name}.pid")
    w.log           = File.join(app_root, 'log', "#{name}.log")

  
    # run sidekiq as daemon
    sidekiq_options = "-e #{rails_env} -t #{stop_timeout}  -c #{concurrency} -C #{app_root}/config/sidekiq.yml -L #{w.log} -P #{w.pid_file}"
    
    w.start = "cd #{app_root}; nohup #{bin_path}/bundle exec sidekiq -d  #{sidekiq_options} 2>&1 &"
    w.stop  = "cd #{app_root} && sidekiqctl stop #{w.pid_file} #{stop_timeout} "

    
    #w.stop  = "kill -TERM `cat #{w.pid_file}`"
    #w.stop  = "if [ -d #{app_root} ] && [ -f #{w.pid_file} ] && kill -0 `cat #{w.pid_file}`> /dev/null 2>&1; then cd #{app_root} && #{bin_path}/bundle exec sidekiqctl stop #{w.pid_file} 10 ; else echo 'Sidekiq is not running'; fi"


  
    #
    w.keepalive
    w.behavior(:clean_pid_file)

...


  end
end
```

Find the whole file in this gist below.



Use different values for each application:

```ruby
rails_env = 'production'
rake_root = "/home/myuser/.rvm/wrappers/ruby-2.3.3"
bin_path   = "/home/myuser/.rvm/gems/ruby-2.3.3/bin/"

app_root = "/var/www/apps/app4/current"
name_prefix = "god-sidekiq-#{rails_env}"



num_workers = 1

# below is the same as before
...
```


### Stop timeout period for Sidekiq

Eventually we need to restart Sidekiq, for example, after deploy.
If you have long running jobs and Sidekiq is restarting then you might lose your jobs and jobs wouldn't finish.
When Sidekiq is stopping we want to tell Sidekiq to wait until our running jobs finish.

When Sidekiq restarts it receives TERM signals.
Sidekiq should shut down within the -t timeout option.
Any workers that do not finish within the timeout are forcefully terminated and their messages are lost. The timeout defaults to 8 seconds.


* Specify timeout in Sidekiq config sidekiq.yml

```
---
:timeout: 30

:queues:
  - default
  - mailers
  
```


Stop Sidekiq using sidekiqctl runtime utility and use stop timeout = 60 seconds.

* config for god

```

stop_timeout = 60


God.watch do |w|
 ...
    # run sidekiq as daemon
    sidekiq_options = "-e #{rails_env} -t #{stop_timeout}  -c #{concurrency} -C #{app_root}/config/sidekiq.yml -L #{w.log} -P #{w.pid_file}"
    
    w.start = "cd #{app_root}; nohup #{bin_path}/bundle exec sidekiq -d  #{sidekiq_options} 2>&1 &"
    w.stop  = "cd #{app_root} && sidekiqctl stop #{w.pid_file} #{stop_timeout} "


    
    # stop timeout - 30 seconds
    w.stop  = "sidekiqctl stop #{w.pid_file} #{stop_timeout} "

    ...
    
    #
    w.interval      = 30.seconds

    w.start_grace = 20.seconds
    w.restart_grace = 20.seconds

    #w.stop_signal = 'QUIT'
    w.stop_timeout = stop_timeout.seconds
    
    

```


Read more about Signals and Sidekiq - https://github.com/mperham/sidekiq/wiki/Signals


## Run Sidekiq tasks for multiple Rails applications
