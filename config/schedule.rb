job_type :command, ":task :output"
job_type :rake,    "cd :path && :environment_variable=:environment bundle exec rake :task --silent :output"
job_type :runner,  "cd :path && bin/rails runner -e :environment ':task' :output"
job_type :script,  "cd :path && :environment_variable=:environment bundle exec script/:task :output"

# set :output, "/path/to/my/cron_log.log"

every 1.minutes do
    # rake "fetch_nfts:fetch_top_collections", :environment => 'development' 
end