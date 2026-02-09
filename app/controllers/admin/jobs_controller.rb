# frozen_string_literal: true

module Admin
  class JobsController < BaseController
    def index
      @queues = SolidQueue::Queue.all
      @jobs = {
        pending: SolidQueue::Job.where(finished_at: nil).count,
        scheduled: SolidQueue::ScheduledExecution.count,
        failed: SolidQueue::FailedExecution.count,
        completed_today: SolidQueue::Job.where("finished_at > ?", Time.current.beginning_of_day).count
      }

      @recent_failed = SolidQueue::FailedExecution.includes(:job)
                                                   .order(created_at: :desc)
                                                   .limit(20)

      @recurring = recurring_jobs
    end

    def pause_all
      SolidQueue::Queue.all.each(&:pause)
      redirect_to admin_jobs_path, notice: "All queues paused."
    end

    def resume_all
      SolidQueue::Queue.all.each(&:resume)
      redirect_to admin_jobs_path, notice: "All queues resumed."
    end

    def run_tier0_refresh
      Tier0RefreshJob.perform_later
      redirect_to admin_jobs_path, notice: "Tier 0 refresh job queued."
    end

    private

    def recurring_jobs
      config_path = Rails.root.join("config/recurring.yml")
      return {} unless File.exist?(config_path)

      config = YAML.load_file(config_path, aliases: true) || {}
      env_config = config[Rails.env] || config["production"] || {}

      env_config.map do |name, job|
        {
          name: name,
          class: job["class"] || "command",
          schedule: job["schedule"],
          queue: job["queue"] || "default"
        }
      end
    end
  end
end
