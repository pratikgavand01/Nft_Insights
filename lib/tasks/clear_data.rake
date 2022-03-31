namespace :clear_data do
  desc "Clear Previous data from redis"
  task :previous_posted_data => [:environment] do |task, args|
    aa = Kredis.json "recent_top_collections"
    updated_data = aa.value.to_a[-2..-1].to_h
    aa.value = updated_data
  end
end