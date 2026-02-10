# frozen_string_literal: true

module Agents
  class SubmissionsController < ApplicationController
    def new
      @pending_agent = PendingAgent.new
    end

    def create
      @pending_agent = PendingAgent.new(submission_params)
      @pending_agent.status = "pending"
      @pending_agent.discovered_at = Time.current

      # Extract name from GitHub URL if not provided
      @pending_agent.name ||= extract_repo_name(@pending_agent.github_url)

      # Check for duplicates
      duplicate_error = check_for_duplicates(@pending_agent.github_url)
      if duplicate_error
        @pending_agent.errors.add(:github_url, duplicate_error)
        render :new, status: :unprocessable_content
        return
      end

      if @pending_agent.save
        @pending_agent.queue_ai_review!
        redirect_to new_agent_submissions_path, notice: "Thanks for your submission! We'll review #{@pending_agent.name} and add it to Evald if it meets our criteria."
      else
        render :new, status: :unprocessable_content
      end
    end

    private

    def submission_params
      params.expect(pending_agent: [:github_url, :description])
    end

    def extract_repo_name(github_url)
      return nil if github_url.blank?

      # Extract owner/repo from URL like https://github.com/owner/repo
      match = github_url.match(%r{github\.com/([^/]+)/([^/]+)/?$})
      return nil unless match

      "#{match[1]}/#{match[2]}"
    end

    def check_for_duplicates(github_url)
      return nil if github_url.blank?

      # Check if already in pending_agents
      if PendingAgent.exists?(github_url: github_url)
        existing = PendingAgent.find_by(github_url: github_url)
        case existing.status
        when "pending"
          return "has already been submitted and is pending review"
        when "approved"
          return "has already been approved"
        when "rejected"
          return "was previously reviewed and rejected"
        end
      end

      # Check if already an evaluated agent
      # Match against github_repo field in agents table
      repo_path = github_url.sub(%r{^https://github\.com/}, "")
      if Agent.exists?(github_repo: repo_path) || Agent.exists?(github_repo: "https://github.com/#{repo_path}")
        return "is already being tracked on Evald"
      end

      nil
    end
  end
end
