namespace :fetch_nfts do
  desc "Fetch and store events data fro Created Event"
  task :listed_events_backfiling => [:environment] do |task, args|
    Rails.logger.info "******************Created*************************"
    start_time = Time.now.utc.strftime('%Y-%m-%dT%H:%M:%S')
    # end_time = (Time.now.utc - 1.minutes).strftime('%Y-%m-%dT%H:%M:%S')
    last_delta_job_activity = JobsActivity.where(job_type: 1, job_name: "created_events").last
    last_all_job_activity = JobsActivity.where(job_type: 0, job_name: "created_events").last
    if last_all_job_activity.present?
      if last_delta_job_activity.present?
        OpenseaRequests.fetch_events("delta", start_time, "created") if %w[active paused].include?(last_delta_job_activity.status)
      else
        OpenseaRequests.fetch_events("delta", start_time, "created")
      end
    end
  end

  desc "Fetch and store events data fro Successful Event"
  task :successful_events_backfiling => [:environment] do |task, args|
    Rails.logger.info "******************Successful*************************"
    start_time = Time.now.utc.strftime('%Y-%m-%dT%H:%M:%S')
    # end_time = (Time.now.utc - 1.minutes).strftime('%Y-%m-%dT%H:%M:%S')
    last_delta_job_activity = JobsActivity.where(job_type: 1, job_name: "successful_events").last
    last_all_job_activity = JobsActivity.where(job_type: 0, job_name: "successful_events").last
    if last_all_job_activity.present?
      if last_delta_job_activity.present?
        OpenseaRequests.fetch_events("delta", start_time, "successful") if %w[active paused].include?(last_delta_job_activity.status)
      else
        OpenseaRequests.fetch_events("delta", start_time, "successful")
      end
    end
  end

  desc "Fetch and store events data fro Cancelled Event"
  task :cancelled_events_backfiling => [:environment] do |task, args|
    Rails.logger.info "******************Cancelled*************************"
    start_time = Time.now.utc.strftime('%Y-%m-%dT%H:%M:%S')
    # end_time = (Time.now.utc - 1.minutes).strftime('%Y-%m-%dT%H:%M:%S')
    last_delta_job_activity = JobsActivity.where(job_type: 1, job_name: "cancelled_events").last
    last_all_job_activity = JobsActivity.where(job_type: 0, job_name: "cancelled_events").last
    if last_all_job_activity.present?
      if last_delta_job_activity.present?
        OpenseaRequests.fetch_events("delta", start_time, "cancelled") if %w[active paused].include?(last_delta_job_activity.status)
      else
        OpenseaRequests.fetch_events("delta", start_time, "cancelled")
      end
    end
  end

  desc "Fetch past data and store events data fro created Event"
  task :historic_created_events_backfiling => [:environment] do |task, args|
    start_time = Time.now.utc.strftime('%Y-%m-%dT%H:%M:%S')
    OpenseaRequests.fetch_events("past_data", start_time, "created")
  end

  desc "Fetch past data and store events data fro successful Event"
  task :historic_successful_events_backfiling => [:environment] do |task, args|
    start_time = Time.now.utc.strftime('%Y-%m-%dT%H:%M:%S')
    OpenseaRequests.fetch_events("past_data", start_time, "successful")
  end

  desc "Fetch past data and store events data fro Cancelled Event"
  task :historic_cancelled_events_backfiling => [:environment] do |task, args|
    start_time = Time.now.utc.strftime('%Y-%m-%dT%H:%M:%S')
    OpenseaRequests.fetch_events("past_data", start_time, "cancelled")
  end

  desc "Fetch Top collection and posted to Discord"
  task fetch_top_collections: :environment do
    IcyRequest.fetch_collections_and_post_to_discord
  end

  desc "Retry past data failed job"
  task :retry_past_data_job, [:event_type] => :environment do |task, args|
    args.with_defaults(event_type: 'created')
    job_activity = JobsActivity.find_by(job_name: "#{args[:event_type]}_events", job_type: 'past_data')
    if job_activity.present? && %w[terminate failed].include?(job_activity.status)
      OpenseaRequests.retry_events(job_activity)
    end
  end

  desc "Retry paused job"
  task :retry_paused_job, [:job_type, :event_type] => :environment do |task, args|
    args.with_defaults(job_type: 'past_data')
    job_activity = JobsActivity.paused.where(job_type: args[:job_type]).first
    OpenseaRequests.retry_events(job_activity) if job_activity.present?
  end

end
