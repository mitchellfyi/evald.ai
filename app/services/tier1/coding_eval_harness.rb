# frozen_string_literal: true

require "open3"

module Tier1
  # CodingEvalHarness evaluates coding agents by running them against
  # standardized coding tasks in isolated sandbox environments.
  #
  # The harness:
  # 1. Sets up an isolated sandbox environment
  # 2. Loads the initial code state for the task
  # 3. Runs the agent with the task prompt
  # 4. Applies the agent's code changes
  # 5. Runs the test suite
  # 6. Returns comprehensive metrics
  #
  class CodingEvalHarness
    SANDBOX_BASE_PATH = Rails.root.join("tmp", "sandboxes").freeze
    AGENT_TIMEOUT_SECONDS = 300
    TEST_TIMEOUT_SECONDS = 60

    Result = Struct.new(
      :completed,
      :tests_passed,
      :tests_total,
      :accuracy,
      :duration_ms,
      :error,
      :agent_output,
      keyword_init: true
    )

    class SandboxError < StandardError; end
    class AgentError < StandardError; end
    class TestError < StandardError; end

    def initialize(agent, task)
      @agent = agent
      @task = task
      @sandbox_path = nil
      @start_time = nil
    end

    # Main entry point - runs the full evaluation pipeline
    #
    # @return [Result] evaluation results with metrics
    def run
      @start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)

      setup_sandbox
      load_initial_state
      agent_output = run_agent
      apply_agent_changes(agent_output)
      test_results = run_tests

      build_result(
        completed: true,
        tests_passed: test_results[:passed],
        tests_total: test_results[:total],
        agent_output: agent_output
      )
    rescue SandboxError, AgentError, TestError => e
      build_result(completed: false, error: e.message)
    rescue StandardError => e
      Rails.logger.error("[CodingEvalHarness] Unexpected error: #{e.class} - #{e.message}")
      Rails.logger.error(e.backtrace.first(10).join("\n"))
      build_result(completed: false, error: "Unexpected error: #{e.message}")
    ensure
      cleanup_sandbox
    end

    private

    # Sets up an isolated sandbox directory for the evaluation
    def setup_sandbox
      @sandbox_path = SANDBOX_BASE_PATH.join(sandbox_id)

      FileUtils.mkdir_p(@sandbox_path)
      Rails.logger.info("[CodingEvalHarness] Created sandbox: #{@sandbox_path}")
    rescue Errno::EACCES, Errno::ENOENT => e
      raise SandboxError, "Failed to create sandbox: #{e.message}"
    end

    # Loads the initial code state from the task into the sandbox
    def load_initial_state
      initial_files = @task.initial_files || {}

      initial_files.each do |path, content|
        file_path = @sandbox_path.join(path)
        FileUtils.mkdir_p(File.dirname(file_path))
        File.write(file_path, content)
      end

      # Copy test files if specified
      if @task.test_files.present?
        @task.test_files.each do |path, content|
          file_path = @sandbox_path.join(path)
          FileUtils.mkdir_p(File.dirname(file_path))
          File.write(file_path, content)
        end
      end

      Rails.logger.info("[CodingEvalHarness] Loaded #{initial_files.size} initial files")
    rescue StandardError => e
      raise SandboxError, "Failed to load initial state: #{e.message}"
    end

    # Runs the agent with the task prompt and captures output
    #
    # @return [String] the agent's response/code changes
    def run_agent
      prompt = build_agent_prompt

      response = execute_agent_request(prompt)

      unless response[:success]
        raise AgentError, "Agent failed to respond: #{response[:error]}"
      end

      response[:output]
    end

    # Executes the agent API request
    #
    # @param prompt [String] the prompt to send to the agent
    # @return [Hash] response with :success, :output, and :error keys
    def execute_agent_request(prompt)
      # If the agent has an API endpoint, use it
      if @agent.api_endpoint.present?
        execute_http_agent_request(prompt)
      else
        # For agents without API endpoints, simulate or use a stub
        execute_local_agent(prompt)
      end
    end

    # Executes an HTTP request to the agent's API endpoint
    def execute_http_agent_request(prompt)
      uri = URI.parse(@agent.api_endpoint)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == "https"
      http.read_timeout = AGENT_TIMEOUT_SECONDS

      request = Net::HTTP::Post.new(uri.path.presence || "/")
      request.content_type = "application/json"
      request["Authorization"] = "Bearer #{@agent.api_key}" if @agent.api_key.present?
      request.body = { prompt: prompt, task_id: @task.id }.to_json

      response = http.request(request)

      if response.code.to_i == 200
        body = JSON.parse(response.body)
        { success: true, output: body["response"] || body["output"] || body["content"] }
      else
        { success: false, error: "HTTP #{response.code}: #{response.body.truncate(200)}" }
      end
    rescue Net::ReadTimeout
      { success: false, error: "Agent timed out after #{AGENT_TIMEOUT_SECONDS}s" }
    rescue StandardError => e
      { success: false, error: e.message }
    end

    # Executes a local/stub agent for testing or agents without API endpoints
    def execute_local_agent(prompt)
      # This can be extended to support local CLI agents or Docker-based agents
      Rails.logger.warn("[CodingEvalHarness] Using stub agent - no API endpoint configured")
      { success: true, output: "" }
    end

    # Builds the prompt to send to the agent
    #
    # @return [String] the complete prompt including task context
    def build_agent_prompt
      <<~PROMPT
        #{@task.prompt}

        ## Initial Files
        #{format_files_for_prompt(@task.initial_files)}

        ## Instructions
        Provide your solution as code changes. Format each file change as:

        ```path/to/file.ext
        <file content>
        ```

        Only include files that need to be created or modified.
      PROMPT
    end

    # Formats file contents for inclusion in the prompt
    def format_files_for_prompt(files)
      return "No initial files." if files.blank?

      files.map do |path, content|
        "### #{path}\n```\n#{content}\n```"
      end.join("\n\n")
    end

    # Applies the agent's code changes to the sandbox
    #
    # @param agent_output [String] the agent's response containing code changes
    def apply_agent_changes(agent_output)
      return if agent_output.blank?

      changes = parse_agent_output(agent_output)

      changes.each do |path, content|
        file_path = @sandbox_path.join(sanitize_path(path))
        FileUtils.mkdir_p(File.dirname(file_path))
        File.write(file_path, content)
      end

      Rails.logger.info("[CodingEvalHarness] Applied #{changes.size} file changes")
    rescue StandardError => e
      raise AgentError, "Failed to apply agent changes: #{e.message}"
    end

    # Parses code blocks from agent output
    #
    # @param output [String] the agent's raw output
    # @return [Hash] mapping of file paths to content
    def parse_agent_output(output)
      changes = {}

      # Match code blocks with file paths: ```path/to/file.ext\ncontent\n```
      output.scan(/```(\S+)\n(.*?)```/m) do |path, content|
        # Skip language-only code blocks (e.g., ```ruby)
        next if path.match?(/\A(ruby|python|javascript|js|ts|go|rust|java|c|cpp|sh|bash|json|yaml|yml|html|css|sql)\z/i)

        changes[path] = content.strip
      end

      changes
    end

    # Sanitizes file paths to prevent directory traversal
    def sanitize_path(path)
      # Remove any directory traversal attempts
      path.gsub(/\.\./, "").gsub(%r{^/}, "")
    end

    # Runs the test suite in the sandbox
    #
    # @return [Hash] test results with :passed and :total keys
    def run_tests
      test_command = @task.test_command.presence || detect_test_command

      unless test_command
        Rails.logger.warn("[CodingEvalHarness] No test command available")
        return { passed: 0, total: 0 }
      end

      output, status = execute_in_sandbox(test_command)

      parse_test_results(output, status)
    rescue StandardError => e
      raise TestError, "Test execution failed: #{e.message}"
    end

    # Detects the appropriate test command based on project files
    #
    # @return [String, nil] the detected test command or nil
    def detect_test_command
      if File.exist?(@sandbox_path.join("package.json"))
        "npm test"
      elsif File.exist?(@sandbox_path.join("Gemfile"))
        "bundle exec rspec"
      elsif File.exist?(@sandbox_path.join("pytest.ini")) || File.exist?(@sandbox_path.join("setup.py"))
        "pytest"
      elsif File.exist?(@sandbox_path.join("go.mod"))
        "go test ./..."
      end
    end

    # Executes a command in the sandbox with timeout
    #
    # @param command [String] the command to execute
    # @return [Array<String, Process::Status>] output and status
    def execute_in_sandbox(command)
      output = nil
      status = nil

      Dir.chdir(@sandbox_path) do
        Timeout.timeout(TEST_TIMEOUT_SECONDS) do
          output, status = Open3.capture2e(command)
        end
      end

      [ output, status ]
    rescue Timeout::Error
      raise TestError, "Tests timed out after #{TEST_TIMEOUT_SECONDS}s"
    end

    # Parses test output to extract pass/fail counts
    #
    # @param output [String] test command output
    # @param status [Process::Status] exit status
    # @return [Hash] results with :passed and :total keys
    def parse_test_results(output, status)
      # Try to parse common test output formats
      results = { passed: 0, total: 0 }

      # RSpec format: "10 examples, 2 failures"
      if output =~ /(\d+) examples?, (\d+) failures?/
        total = $1.to_i
        failed = $2.to_i
        results = { passed: total - failed, total: total }

      # Jest/Mocha format: "Tests: 2 failed, 8 passed, 10 total"
      elsif output =~ /(\d+) passed.*?(\d+) total/
        results = { passed: $1.to_i, total: $2.to_i }

      # pytest format: "10 passed, 2 failed"
      elsif output =~ /(\d+) passed/
        passed = $1.to_i
        failed = output.match(/(\d+) failed/)&.captures&.first.to_i
        results = { passed: passed, total: passed + failed }

      # Go test format: "ok" or "FAIL"
      elsif output.include?("ok") || output.include?("FAIL")
        passed = output.scan(/^ok/).count
        failed = output.scan(/^FAIL/).count
        results = { passed: passed, total: passed + failed }

      # Fallback: success if exit code is 0
      elsif status.success?
        results = { passed: 1, total: 1 }
      end

      results
    end

    # Cleans up the sandbox directory
    def cleanup_sandbox
      return unless @sandbox_path&.exist?

      FileUtils.rm_rf(@sandbox_path)
      Rails.logger.info("[CodingEvalHarness] Cleaned up sandbox: #{@sandbox_path}")
    rescue StandardError => e
      Rails.logger.error("[CodingEvalHarness] Failed to cleanup sandbox: #{e.message}")
    end

    # Generates a unique sandbox ID
    #
    # @return [String] unique identifier for this evaluation run
    def sandbox_id
      @sandbox_id ||= "eval_#{@agent.id}_#{@task.id}_#{SecureRandom.hex(8)}"
    end

    # Calculates the elapsed duration in milliseconds
    #
    # @return [Integer] duration in milliseconds
    def duration_ms
      return 0 unless @start_time

      elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - @start_time
      (elapsed * 1000).to_i
    end

    # Builds a Result struct with calculated metrics
    #
    # @param completed [Boolean] whether the evaluation completed
    # @param tests_passed [Integer] number of tests passed
    # @param tests_total [Integer] total number of tests
    # @param error [String, nil] error message if failed
    # @param agent_output [String, nil] the agent's output
    # @return [Result] the result struct
    def build_result(completed:, tests_passed: 0, tests_total: 0, error: nil, agent_output: nil)
      accuracy = tests_total.positive? ? (tests_passed.to_f / tests_total).round(4) : 0.0

      Result.new(
        completed: completed,
        tests_passed: tests_passed,
        tests_total: tests_total,
        accuracy: accuracy,
        duration_ms: duration_ms,
        error: error,
        agent_output: agent_output
      )
    end
  end
end
