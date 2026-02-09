# frozen_string_literal: true
module Api
  module V1
    class McpController < BaseController
      include ApiAuthenticatable

      # POST /api/v1/mcp
      # Handles MCP (Model Context Protocol) JSON-RPC 2.0 messages
      # Supports: initialize, tools/list, tools/call

      rescue_from ActionDispatch::Http::Parameters::ParseError, with: :handle_parse_error

      def handle
        body = parse_request_body
        return render_jsonrpc_error(nil, -32700, "Parse error") unless body

        if body.is_a?(Array)
          responses = body.map { |msg| process_message(msg) }.compact
          render json: responses, status: :ok
        else
          response = process_message(body)
          if response
            render json: response, status: :ok
          else
            head :accepted
          end
        end
      end

      private

      def handler
        @handler ||= McpToolHandler.new
      end

      def parse_request_body
        JSON.parse(request.body.read)
      rescue JSON::ParserError
        nil
      end

      def process_message(msg)
        id = msg.is_a?(Hash) ? msg["id"] : nil
        return render_jsonrpc_error(id, -32600, "Invalid Request") unless valid_jsonrpc?(msg)

        method = msg["method"]
        params = msg["params"] || {}

        # Notifications (no id) don't get responses
        case method
        when "initialize"
          handle_initialize(id, params)
        when "notifications/initialized"
          nil # No response for notifications
        when "tools/list"
          handle_tools_list(id)
        when "tools/call"
          handle_tools_call(id, params)
        when "ping"
          jsonrpc_response(id, {})
        else
          render_jsonrpc_error(id, -32601, "Method not found: #{method}")
        end
      end

      def valid_jsonrpc?(msg)
        msg.is_a?(Hash) && msg["jsonrpc"] == "2.0" && msg["method"].is_a?(String)
      end

      def handle_initialize(id, params)
        jsonrpc_response(id, {
          protocolVersion: McpToolHandler::PROTOCOL_VERSION,
          capabilities: handler.server_capabilities,
          serverInfo: handler.server_info
        })
      end

      def handle_tools_list(id)
        jsonrpc_response(id, { tools: handler.list_tools })
      end

      def handle_tools_call(id, params)
        tool_name = params["name"]
        raw_arguments = params["arguments"]

        unless tool_name.present?
          return render_jsonrpc_error(id, -32602, "Invalid params: tool name required")
        end

        arguments =
          if raw_arguments.nil?
            {}
          elsif raw_arguments.is_a?(Hash)
            raw_arguments
          else
            return render_jsonrpc_error(id, -32602, "Invalid params: arguments must be an object")
          end

        content = handler.call_tool(tool_name, arguments)
        is_error = content.any? { |c| c[:isError] }

        jsonrpc_response(id, { content: content, isError: is_error || nil }.compact)
      end

      def jsonrpc_response(id, result)
        { jsonrpc: "2.0", id: id, result: result }
      end

      def render_jsonrpc_error(id, code, message)
        { jsonrpc: "2.0", id: id, error: { code: code, message: message } }
      end

      def handle_parse_error(_exception)
        render json: render_jsonrpc_error(nil, -32700, "Parse error"), status: :ok
      end
    end
  end
end
