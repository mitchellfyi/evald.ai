module Api
  module V1
    class TelemetryController < BaseController
      def create
        @telemetry_event = TelemetryEvent.new(telemetry_event_params)
        @telemetry_event.received_at ||= Time.current

        if @telemetry_event.save
          head :created
        else
          render json: { errors: @telemetry_event.errors.full_messages }, status: :unprocessable_entity
        end
      end

      private

      def telemetry_event_params
        params.require(:telemetry_event).permit(:agent_id, :event_type, :received_at, metrics: {}, metadata: {})
      end
    end
  end
end
