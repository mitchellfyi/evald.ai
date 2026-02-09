# frozen_string_literal: true

module Tier1
  # SandboxManager handles the creation and management of isolated Docker containers
  # for secure code evaluation. Each sandbox runs with restricted resources and
  # provides methods for file manipulation, test execution, and cleanup.
  class SandboxManager
    RESOURCE_LIMITS = {
      memory: "512m",
      cpus: 1,
      timeout: 300
    }.freeze

    SUPPORTED_LANGUAGES = %w[python ruby javascript].freeze
    DOCKER_IMAGE = "evaled-sandbox:latest"

    class SandboxError < StandardError; end
    class UnsupportedLanguageError < SandboxError; end
    class ContainerError < SandboxError; end
    class TimeoutError < SandboxError; end

    # Creates a new sandbox container for the specified language
    #
    # @param language [String] The programming language (python, ruby, javascript)
    # @return [Sandbox] A sandbox instance for interacting with the container
    # @raise [UnsupportedLanguageError] If the language is not supported
    def create_sandbox(language:)
      language = language.to_s.downcase
      validate_language!(language)

      container_id = start_container(language)
      Sandbox.new(container_id: container_id, language: language, manager: self)
    rescue Docker::Error::DockerError => e
      raise ContainerError, "Failed to create sandbox: #{e.message}"
    end

    # Lists all running sandbox containers
    #
    # @return [Array<String>] Container IDs of running sandboxes
    def list_sandboxes
      output = execute_docker_command("docker ps -q --filter 'label=evaled.sandbox=true'")
      output.split("\n").reject(&:empty?)
    end

    # Cleans up all sandbox containers older than the specified age
    #
    # @param max_age_seconds [Integer] Maximum age in seconds (default: 1 hour)
    # @return [Array<String>] Container IDs that were cleaned up
    def cleanup_stale_containers(max_age_seconds: 3600)
      cleaned = []
      list_sandboxes.each do |container_id|
        created_at = get_container_created_at(container_id)
        age = Time.current - created_at
        if age > max_age_seconds
          stop_and_remove_container(container_id)
          cleaned << container_id
        end
      end
      cleaned
    end

    private

    def validate_language!(language)
      return if SUPPORTED_LANGUAGES.include?(language)

      raise UnsupportedLanguageError,
            "Language '#{language}' is not supported. Supported: #{SUPPORTED_LANGUAGES.join(', ')}"
    end

    def start_container(language)
      container_name = "evaled-sandbox-#{SecureRandom.hex(8)}"
      cmd = build_docker_run_command(container_name, language)
      output = execute_docker_command(cmd)
      output.strip
    end

    def build_docker_run_command(name, language)
      [
        "docker run -d",
        "--name #{name}",
        "--label evaled.sandbox=true",
        "--label evaled.language=#{language}",
        "--memory=#{RESOURCE_LIMITS[:memory]}",
        "--cpus=#{RESOURCE_LIMITS[:cpus]}",
        "--network=none",
        "--read-only",
        "--tmpfs /tmp:rw,noexec,nosuid,size=64m",
        "--tmpfs /eval:rw,exec,size=128m",
        "--security-opt=no-new-privileges:true",
        "--cap-drop=ALL",
        DOCKER_IMAGE,
        "sleep #{RESOURCE_LIMITS[:timeout]}"
      ].join(" ")
    end

    def get_container_created_at(container_id)
      output = execute_docker_command(
        "docker inspect --format='{{.Created}}' #{container_id}"
      )
      Time.parse(output.strip)
    end

    def stop_and_remove_container(container_id)
      execute_docker_command("docker rm -f #{container_id}")
    end

    def execute_docker_command(cmd)
      stdout, stderr, status = Open3.capture3(cmd)
      raise ContainerError, "Docker command failed: #{stderr}" unless status.success?

      stdout
    end

    # Sandbox provides an interface for interacting with an isolated container.
    # It supports file operations, code execution, and test running.
    class Sandbox
      attr_reader :container_id, :language

      def initialize(container_id:, language:, manager:)
        @container_id = container_id
        @language = language
        @manager = manager
        @cleaned_up = false
      end

      # Loads files into the sandbox container
      #
      # @param files [Hash<String, String>] Mapping of filename to content
      # @return [Boolean] true if successful
      def load_files(files)
        ensure_not_cleaned_up!

        files.each do |filename, content|
          safe_filename = sanitize_filename(filename)
          escaped_content = escape_for_shell(content)

          exec_in_container("echo #{escaped_content} > /eval/#{safe_filename}")
        end

        true
      end

      # Applies changes to existing files in the sandbox
      #
      # @param changes [Hash<String, String>] Mapping of filename to new content
      # @return [Boolean] true if successful
      def apply_changes(changes)
        ensure_not_cleaned_up!

        changes.each do |filename, content|
          safe_filename = sanitize_filename(filename)
          escaped_content = escape_for_shell(content)

          exec_in_container("echo #{escaped_content} > /eval/#{safe_filename}")
        end

        true
      end

      # Runs tests in the sandbox and returns results
      #
      # @param test_command [String, nil] Custom test command (optional)
      # @return [Hash] Test results including stdout, stderr, exit_code, and duration
      def run_tests(test_command: nil)
        ensure_not_cleaned_up!

        command = test_command || default_test_command
        start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)

        stdout, stderr, exit_code = exec_in_container_with_status(command)

        duration = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time

        {
          stdout: stdout,
          stderr: stderr,
          exit_code: exit_code,
          duration: duration.round(3),
          passed: exit_code.zero?
        }
      end

      # Executes arbitrary code in the sandbox
      #
      # @param code [String] Code to execute
      # @return [Hash] Execution results
      def execute(code)
        ensure_not_cleaned_up!

        filename = code_filename
        load_files({ filename => code })

        run_command = run_code_command(filename)
        stdout, stderr, exit_code = exec_in_container_with_status(run_command)

        {
          stdout: stdout,
          stderr: stderr,
          exit_code: exit_code,
          success: exit_code.zero?
        }
      end

      # Cleans up the sandbox container
      #
      # @return [Boolean] true if cleanup was successful
      def cleanup
        return true if @cleaned_up

        execute_docker_command("docker rm -f #{@container_id}")
        @cleaned_up = true
        true
      rescue SandboxManager::ContainerError
        @cleaned_up = true
        false
      end

      # Check if sandbox has been cleaned up
      def cleaned_up?
        @cleaned_up
      end

      private

      def ensure_not_cleaned_up!
        raise SandboxManager::SandboxError, "Sandbox has been cleaned up" if @cleaned_up
      end

      def exec_in_container(command)
        execute_docker_command(
          "docker exec #{@container_id} sh -c '#{escape_single_quotes(command)}'"
        )
      end

      def exec_in_container_with_status(command)
        cmd = "docker exec #{@container_id} sh -c '#{escape_single_quotes(command)}'"
        stdout, stderr, status = Open3.capture3(cmd)
        [ stdout, stderr, status.exitstatus ]
      end

      def execute_docker_command(cmd)
        stdout, stderr, status = Open3.capture3(cmd)
        unless status.success?
          raise SandboxManager::ContainerError, "Docker command failed: #{stderr}"
        end

        stdout
      end

      def sanitize_filename(filename)
        # Only allow alphanumeric, dots, underscores, and hyphens
        filename.gsub(/[^a-zA-Z0-9._-]/, "_")
      end

      def escape_for_shell(content)
        # Base64 encode to safely pass content
        encoded = Base64.strict_encode64(content)
        "$(echo '#{encoded}' | base64 -d)"
      end

      def escape_single_quotes(str)
        str.gsub("'", "'\"'\"'")
      end

      def default_test_command
        case @language
        when "python"
          "cd /eval && python -m pytest -v 2>&1 || python -m unittest discover -v 2>&1"
        when "ruby"
          "cd /eval && ruby -Ilib -e 'Dir.glob(\"*_test.rb\").each { |f| require \"./#{f}\" }'"
        when "javascript"
          "cd /eval && npm test 2>&1 || node --test 2>&1"
        else
          "echo 'No default test command for #{@language}'"
        end
      end

      def code_filename
        case @language
        when "python" then "code.py"
        when "ruby" then "code.rb"
        when "javascript" then "code.js"
        else "code.txt"
        end
      end

      def run_code_command(filename)
        case @language
        when "python" then "cd /eval && python #{filename}"
        when "ruby" then "cd /eval && ruby #{filename}"
        when "javascript" then "cd /eval && node #{filename}"
        else "cat /eval/#{filename}"
        end
      end
    end
  end
end
