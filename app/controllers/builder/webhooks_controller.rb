# frozen_string_literal: true
module Builder
  class WebhooksController < BaseController
    before_action :set_agent
    before_action :authorize_agent
    before_action :set_webhook, only: [:show, :destroy, :toggle, :regenerate_secret]

    def index
      @webhooks = @agent.webhook_endpoints.order(created_at: :desc)
    end

    def new
      @webhook = @agent.webhook_endpoints.build
    end

    def create
      @webhook = @agent.webhook_endpoints.build(webhook_params)
      @webhook.secret = SecureRandom.hex(32)

      if @webhook.save
        redirect_to builder_agent_webhooks_path(@agent), notice: "Webhook created successfully."
      else
        render :new, status: :unprocessable_content
      end
    end

    def show
      @deliveries = @webhook.webhook_deliveries.recent.limit(50)
    end

    def destroy
      @webhook.destroy
      redirect_to builder_agent_webhooks_path(@agent), notice: "Webhook deleted."
    end

    def toggle
      if @webhook.enabled?
        @webhook.update!(enabled: false, disabled_at: Time.current)
        notice = "Webhook disabled."
      else
        @webhook.reenable!
        notice = "Webhook re-enabled."
      end
      redirect_to builder_agent_webhooks_path(@agent), notice: notice
    end

    def regenerate_secret
      @webhook.regenerate_secret!
      redirect_to builder_agent_webhook_path(@agent, @webhook), notice: "Secret regenerated. Update your endpoint to use the new secret."
    end

    private

    def set_agent
      @agent = Agent.find_by!(slug: params[:agent_id])
    end

    def authorize_agent
      unless @agent.claimed_by_user == current_user
        redirect_to builder_root_path, alert: "You don't have permission to manage webhooks for this agent."
      end
    end

    def set_webhook
      @webhook = @agent.webhook_endpoints.find(params[:id])
    end

    def webhook_params
      params.expect(webhook_endpoint: [:url, events: []])
    end
  end
end
