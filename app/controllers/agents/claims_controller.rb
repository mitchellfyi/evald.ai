# frozen_string_literal: true
module Agents
  class ClaimsController < ApplicationController
    before_action :set_agent
    before_action :authenticate_user!, only: %i[create verify]

    def create
      @claim_request = ClaimRequest.new(
        agent: @agent,
        user: current_user,
        requested_at: Time.current
      )

      if @claim_request.save
        redirect_to agent_profile_path(@agent),
                    notice: "Claim request submitted. Please verify your ownership."
      else
        redirect_to agent_profile_path(@agent),
                    alert: @claim_request.errors.full_messages.join(", ")
      end
    end

    def verify
      @claim_request = ClaimRequest.pending_claims.find_by!(
        agent: @agent,
        user: current_user
      )

      verification_result = verify_github_ownership

      if verification_result[:verified]
        @claim_request.verify!(verification_result)
        @agent.update!(
          claimed_by_user: current_user,
          claim_status: "claimed",
          claimed_at: Time.current
        )
        NotificationPreference.find_or_create_by!(user: current_user, agent: @agent)
        redirect_to agent_profile_path(@agent),
                    notice: "Ownership verified! You now manage this agent."
      else
        redirect_to agent_profile_path(@agent),
                    alert: "Verification failed: #{verification_result[:reason]}"
      end
    end

    private

    def set_agent
      @agent = Agent.published.find_by!(slug: params[:agent_id])
    end

    def verify_github_ownership
      return { verified: false, reason: "No GitHub account linked" } unless current_user&.github_username

      github_repo = @agent.github_repo
      return { verified: false, reason: "No GitHub repo configured for this agent" } unless github_repo

      if verify_repo_access(github_repo, current_user.github_username)
        {
          verified: true,
          method: "repo_access",
          github_username: current_user.github_username,
          verified_at: Time.current.iso8601
        }
      else
        { verified: false, reason: "You don't have write or admin access to #{github_repo}" }
      end
    end

    def verify_repo_access(repo, username)
      # Parse repo into owner/name format
      parts = repo.gsub(%r{^https?://github\.com/}, "").split("/")
      return false unless parts.length >= 2

      owner = parts[0]
      name = parts[1].sub(/\.git$/, "")

      client = GithubClient.new
      permission_data = client.collaborator_permission(owner, name, username)

      return false unless permission_data

      # Require write, admin, or maintain permission for verification
      permission = permission_data["permission"]
      %w[ admin maintain write ].include?(permission)
    rescue GithubClient::RateLimitError
      Rails.logger.warn("GitHub API rate limit hit during claim verification for #{repo}")
      false
    rescue StandardError => e
      Rails.logger.error("GitHub verification error for #{repo}: #{e.message}")
      false
    end
  end
end
