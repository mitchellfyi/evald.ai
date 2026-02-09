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
          claim_status: "verified"
        )
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

    def authenticate_user!
      redirect_to root_path, alert: "Please sign in to claim an agent." unless current_user
    end

    def current_user
      # TODO: Implement proper authentication (Devise, etc.)
      # For now, check session or return nil
      @current_user ||= User.find_by(id: session[:user_id])
    end

    def verify_github_ownership
      # Verification methods:
      # 1. Check if user's GitHub account matches the agent's repo owner
      # 2. Verify user has push access to the repo
      # 3. Check for verification file in repo (.evaled-verify.txt)

      return { verified: false, reason: "No GitHub account linked" } unless current_user&.github_username

      github_repo = @agent.github_repo
      return { verified: false, reason: "No GitHub repo configured for this agent" } unless github_repo

      # Check if user owns or has admin access to the repo
      if verify_repo_access(github_repo, current_user.github_username)
        {
          verified: true,
          method: "repo_access",
          github_username: current_user.github_username,
          verified_at: Time.current.iso8601
        }
      else
        { verified: false, reason: "You don't have admin access to #{github_repo}" }
      end
    end

    def verify_repo_access(repo, username)
      # TODO: Implement actual GitHub API check
      # For now, return false (requires implementation)
      # This would use Octokit or HTTP to check:
      # GET /repos/{owner}/{repo}/collaborators/{username}/permission
      false
    end
  end
end
