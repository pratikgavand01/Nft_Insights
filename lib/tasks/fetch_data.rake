namespace :fetch_data do

  desc "Fetch and store events data for Event"
  task :listed_events_backfiling, [:event_type] => [:environment] do |task, args|
    start_time = Time.now.utc.strftime('%Y-%m-%dT%H:%M:%S')
    last_delta_job_activity = JobsActivity.where(job_type: 1, job_name: "#{args[:event_type]}_events").last
    last_all_job_activity = JobsActivity.where(job_type: 0, job_name: "#{args[:event_type]}_events").last
    if last_all_job_activity.present?
      if last_delta_job_activity.present?
        OpenseaRequests.fetch_events("delta", start_time, args[:event_type]) unless %w[active paused].include?(last_delta_job_activity.status)
      else
        OpenseaRequests.fetch_events("delta", start_time, args[:event_type])
      end
    end
  end

  desc "Fetch past data and store events data"
  task :historic_events_backfiling, [:event_type] => [:environment] do |task, args|
    start_time = Time.now.utc.strftime('%Y-%m-%dT%H:%M:%S')
    args.with_defaults(event_type: 'created')
    OpenseaRequests.fetch_events("past_data", start_time, args[:event_type])
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

  desc "Retry failed event fetch job"
  task :retry_failed_events, [:job_type, :event_type] => :environment do |task, args|
    args.with_defaults(job_type: 'past_data')
    args.with_defaults(event_type: 'created')
    job_activity = JobsActivity.where(job_type: args[:job_type], job_name: "#{args[:event_type]}_events", status: [:failed, :terminate]).first
    OpenseaRequests.retry_events(job_activity) if job_activity.present?
  end

  desc "Retry paused job"
  task :retry_paused_job, [:job_type, :event_type] => :environment do |task, args|
    args.with_defaults(job_type: 'past_data')
    args.with_defaults(event_type: 'created')
    job_activity = JobsActivity.paused.where(job_type: args[:job_type], job_name: "#{args[:event_type]}_events").first
    OpenseaRequests.retry_events(job_activity) if job_activity.present?
  end

end
