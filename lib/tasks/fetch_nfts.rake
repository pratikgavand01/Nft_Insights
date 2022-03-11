namespace :fetch_nfts do
  desc "TODO"
  task fetch_top_collections: :environment do
       IcyRequest.get_and_set_top_collections
  end

  desc "TODO"
  task :fetch_all_collection_event_by_type, [:slug, :type] => [:environment] do |task, args|
    OpenseaRequests.set_collection_events_by_type(args[:slug],args[:type])
  end  
  
  end
