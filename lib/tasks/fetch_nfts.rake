namespace :fetch_nfts do
  desc "Fetch and store events data fro Created Event"
  task :listed_events_backfiling => [:environment] do |task, args|
    Rails.logger.info "******************Created*************************"
    start_time = Time.now.utc.strftime('%Y-%m-%dT%H:%M:%S')
    # end_time = (Time.now.utc - 1.minutes).strftime('%Y-%m-%dT%H:%M:%S')
    last_delta_job_activity = JobsActivity.where(job_type: 1, job_name: "created_events").last
    last_all_job_activity = JobsActivity.where(job_type: 0, job_name: "created_events").last
    if last_all_job_activity.present? && (!last_delta_job_activity.present? || !last_delta_job_activity.active?)
      OpenseaRequests.fetch_events("delta", start_time, nil, "created")
    end
  end

  desc "Fetch and store events data fro Successful Event"
  task :successful_events_backfiling => [:environment] do |task, args|
    Rails.logger.info "******************Successful*************************"
    start_time = Time.now.utc.strftime('%Y-%m-%dT%H:%M:%S')
    # end_time = (Time.now.utc - 1.minutes).strftime('%Y-%m-%dT%H:%M:%S')
    last_delta_job_activity = JobsActivity.where(job_type: 1, job_name: "successful_events").last
    last_all_job_activity = JobsActivity.where(job_type: 0, job_name: "successful_events").last
    if last_all_job_activity.present? && (!last_delta_job_activity.present? || !last_delta_job_activity.active?)
      OpenseaRequests.fetch_events("delta", start_time, nil, "successful")
    end
  end

  desc "Fetch and store events data fro Cancelled Event"
  task :cancelled_events_backfiling => [:environment] do |task, args|
    Rails.logger.info "******************Cancelled*************************"
    start_time = Time.now.utc.strftime('%Y-%m-%dT%H:%M:%S')
    # end_time = (Time.now.utc - 1.minutes).strftime('%Y-%m-%dT%H:%M:%S')
    last_delta_job_activity = JobsActivity.where(job_type: 1, job_name: "cancelled_events").last
    last_all_job_activity = JobsActivity.where(job_type: 0, job_name: "cancelled_events").last
    if last_all_job_activity.present? && (!last_delta_job_activity.present? || !last_delta_job_activity.active?)
      OpenseaRequests.fetch_events("delta", start_time, nil, "cancelled")
    end
  end

  desc "Fetch past data and store events data fro created Event"
  task :historic_created_events_backfiling => [:environment] do |task, args|
    start_time = Time.now.utc.strftime('%Y-%m-%dT%H:%M:%S')
    OpenseaRequests.fetch_events("past_data", start_time, nil, "created")
  end

  desc "Fetch past data and store events data fro successful Event"
  task :historic_successful_events_backfiling => [:environment] do |task, args|
    start_time = Time.now.utc.strftime('%Y-%m-%dT%H:%M:%S')
    OpenseaRequests.fetch_events("past_data", start_time, nil, "successful")
  end

  desc "Fetch past data and store events data fro Cancelled Event"
  task :historic_cancelled_events_backfiling => [:environment] do |task, args|
    start_time = Time.now.utc.strftime('%Y-%m-%dT%H:%M:%S')
    OpenseaRequests.fetch_events("past_data", start_time, nil, "cancelled")
  end

  desc "Fetch Top collection and posted to Discord"
  task fetch_top_collections: :environment do
    IcyRequest.fetch_collections_and_post_to_discord
  end

end
