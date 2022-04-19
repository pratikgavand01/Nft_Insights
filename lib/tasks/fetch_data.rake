namespace :fetch_data do

  desc "Fetch and store events data for Event"
  task :listed_events_backfiling, [:event_type] => [:environment] do |task, args|
    start_time = Time.now.utc.strftime('%Y-%m-%dT%H:%M:%S')
    last_delta_job_activity = JobsActivity.where(job_type: 1, job_name: "#{args[:event_type]}_events").last
    last_all_job_activity = JobsActivity.where(job_type: 0, job_name: "#{args[:event_type]}_events").last
    if last_all_job_activity.present?
      if last_delta_job_activity.present?
        OpenSeaService.fetch_events("delta", start_time, args[:event_type]) unless %w[active paused].include?(last_delta_job_activity.status)
      else
        OpenSeaService.fetch_events("delta", start_time, args[:event_type])
      end
    end
  end

  desc "Fetch past data and store events data"
  task :historic_events_backfiling, [:event_type] => [:environment] do |task, args|
    start_time = Time.now.utc.strftime('%Y-%m-%dT%H:%M:%S')
    args.with_defaults(event_type: 'created')
    OpenSeaService.fetch_events("past_data", start_time, args[:event_type])
  end

  desc "Fetch Top collection and posted to Discord"
  task :fetch_top_collections, [:record_time, :sort_by, :records, :limit] => :environment do |task, args|
    args.with_defaults(record_time: "1.hour")
    args.with_defaults(sort_by: 'VOLUME')
    args.with_defaults(records: 100)
    args.with_defaults(limit: 5)
    IcyToolService.fetch_collections_and_post_to_discord(eval(args[:record_time].to_s), args[:sort_by].to_s, args[:records].to_i, args[:limit].to_i)
  end

  desc "Retry past data failed job"
  task :retry_past_data_job, [:event_type] => :environment do |task, args|
    args.with_defaults(event_type: 'created')
    job_activity = JobsActivity.find_by(job_name: "#{args[:event_type]}_events", job_type: 'past_data')
    if job_activity.present? && %w[terminate failed].include?(job_activity.status)
      OpenSeaService.retry_events(job_activity)
    end
  end

  desc "Retry failed event fetch job"
  task :retry_failed_events, [:job_type, :event_type] => :environment do |task, args|
    args.with_defaults(job_type: 'past_data')
    args.with_defaults(event_type: 'created')
    active_jobs = JobsActivity.where(job_type: args[:job_type], job_name: "#{args[:event_type]}_events", status: [:active]).count
    job_activity = JobsActivity.where(job_type: args[:job_type], job_name: "#{args[:event_type]}_events", status: [:failed, :terminate]).first
    if job_activity.present? && active_jobs < 3
      response = false
      until response do
        response = OpenSeaService.retry_events(job_activity)
        job_activity = JobsActivity.where(job_type: args[:job_type], job_name: "#{args[:event_type]}_events", status: [:failed, :terminate]).where.not(id: job_activity.id).first
      end
    end
  end

  desc "Retry paused job"
  task :retry_paused_job, [:job_type, :event_type] => :environment do |task, args|
    args.with_defaults(job_type: 'past_data')
    args.with_defaults(event_type: 'created')
    active_jobs = JobsActivity.where(job_type: args[:job_type], job_name: "#{args[:event_type]}_events", status: [:active]).count
    job_activity = JobsActivity.paused.where(job_type: args[:job_type], job_name: "#{args[:event_type]}_events").first
    OpenSeaService.retry_events(job_activity) if job_activity.present? && active_jobs < 3
  end

end
