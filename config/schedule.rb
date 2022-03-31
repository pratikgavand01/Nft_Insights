job_type :command, ":task :output"
job_type :rake,    "cd :path && :environment_variable=:environment bundle exec rake :task --silent :output"
job_type :runner,  "cd :path && bin/rails runner -e :environment ':task' :output"
job_type :script,  "cd :path && :environment_variable=:environment bundle exec script/:task :output"

set :output, "/var/log/cron.log"

ENV.each { |k, v| env(k, v) }

every 1.minutes do
  rake "fetch_nfts:listed_events_backfiling"
  rake "fetch_nfts:successful_events_backfiling"
  rake "fetch_nfts:cancelled_events_backfiling"
  rake "fetch_nfts:fetch_top_collections"
end

every 1.day, at: '12:00 am' do
  rake "clear_data:previous_posted_data"
end
