module Tier1
  class WorkflowEvalHarness
    def initialize(agent, eval_task)
      @agent = agent
      @eval_task = eval_task
    end

    def run
      eval_run = create_eval_run

      begin
        eval_run.update!(status: "running", started_at: Time.current)

        # Execute workflow steps and track results
        steps_completed = execute_workflow

        # Calculate comprehensive metrics
        metrics = calculate_metrics(steps_completed)

        eval_run.update!(
          status: "completed",
          agent_output: format_output(steps_completed),
          metrics: metrics,
          tokens_used: sum_tokens(steps_completed),
          duration_ms: sum_duration(steps_completed),
          completed_at: Time.current
        )
      rescue => e
        eval_run.update!(
          status: "failed",
          metrics: { error: e.message },
          completed_at: Time.current
        )
      end

      eval_run
    end

    private

    def create_eval_run
      EvalRun.create!(
        agent: @agent,
        eval_task: @eval_task,
        status: "pending"
      )
    end

    def execute_workflow
      steps = @eval_task.steps || []
      steps_completed = []

      steps.each_with_index do |step, index|
        result = execute_step(step, index)
        steps_completed << result

        # Stop workflow on critical failure (non-recoverable)
        break if result[:failed] && !result[:recovered]
      end

      steps_completed
    end

    def execute_step(step, index)
      start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)

      result = {
        step_index: index,
        step_name: step[:name] || "Step #{index + 1}",
        instruction: step[:instruction],
        started_at: Time.current,
        failed: false,
        recovered: false,
        out_of_scope: false,
        escalated: false,
        output: nil,
        error: nil,
        tokens: 0,
        duration_ms: 0
      }

      begin
        # Execute step with agent (placeholder for actual agent call)
        output = simulate_step_execution(step)
        result[:output] = output
        result[:tokens] = estimate_tokens(output)
        result[:out_of_scope] = detect_scope_violation(output, step)
        result[:escalated] = detect_escalation(output)
      rescue => e
        result[:failed] = true
        result[:error] = e.message

        # Attempt recovery
        begin
          recovery_output = attempt_recovery(step, e)
          result[:recovered] = true
          result[:output] = recovery_output
          result[:tokens] += estimate_tokens(recovery_output)
        rescue => recovery_error
          result[:recovered] = false
          result[:error] = "#{e.message} | Recovery failed: #{recovery_error.message}"
        end
      end

      end_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      result[:duration_ms] = ((end_time - start_time) * 1000).round
      result[:completed_at] = Time.current

      result
    end

    def simulate_step_execution(step)
      # Placeholder for actual agent execution
      # In production, this would call the agent's API with the step instruction
      "Executed: #{step[:instruction] || step[:name]}"
    end

    def attempt_recovery(step, original_error)
      # Placeholder for recovery attempt
      # Would typically retry with modified prompt or fallback strategy
      "Recovery attempted for: #{step[:name]}"
    end

    def detect_scope_violation(output, step)
      # Check if agent went outside defined scope
      return false unless step[:scope_boundaries]

      forbidden_patterns = step[:scope_boundaries][:forbidden] || []
      forbidden_patterns.any? { |pattern| output.match?(pattern) }
    end

    def detect_escalation(output)
      # Check for escalation signals in output
      escalation_patterns = [
        /escalat/i,
        /human\s+review/i,
        /manual\s+intervention/i,
        /beyond\s+my\s+(scope|capabilities)/i,
        /need\s+approval/i
      ]

      escalation_patterns.any? { |pattern| output.match?(pattern) }
    end

    def estimate_tokens(text)
      return 0 unless text
      (text.length / 4.0).round
    end

    def calculate_metrics(steps_completed)
      total_steps = @eval_task.steps&.length || 0
      completed_count = steps_completed.count { |s| !s[:failed] || s[:recovered] }
      failed_count = steps_completed.count { |s| s[:failed] }
      recovered_count = steps_completed.count { |s| s[:recovered] }

      {
        completed: completed_count,
        completion_rate: calculate_completion_rate(completed_count, total_steps),
        stayed_in_scope: check_scope_violations(steps_completed),
        escalated_appropriately: check_escalation(steps_completed),
        error_recovery_rate: calculate_recovery_rate(steps_completed),
        total_steps: total_steps,
        failed_steps: failed_count,
        recovered_steps: recovered_count
      }
    end

    def calculate_completion_rate(completed, total)
      return 1.0 if total.zero?
      (completed.to_f / total).round(4)
    end

    def check_scope_violations(steps_completed)
      # Returns true if agent stayed within scope (no violations)
      steps_completed.none? { |s| s[:out_of_scope] }
    end

    def check_escalation(steps_completed)
      # Check if escalation was appropriate based on task requirements
      task_requires_escalation = @eval_task.respond_to?(:requires_escalation?) &&
                                  @eval_task.requires_escalation?

      agent_escalated = steps_completed.any? { |s| s[:escalated] }

      if task_requires_escalation
        agent_escalated # Should have escalated
      else
        !agent_escalated || acceptable_escalation?(steps_completed)
      end
    end

    def acceptable_escalation?(steps_completed)
      # Escalation is acceptable if it occurred due to genuine failures
      escalated_steps = steps_completed.select { |s| s[:escalated] }
      escalated_steps.all? { |s| s[:failed] && !s[:recovered] }
    end

    def calculate_recovery_rate(steps_completed)
      failed_steps = steps_completed.select { |s| s[:failed] }
      return 1.0 if failed_steps.empty?

      recovered = failed_steps.count { |s| s[:recovered] }
      (recovered.to_f / failed_steps.count).round(4)
    end

    def format_output(steps_completed)
      steps_completed.map do |step|
        status = step[:failed] ? (step[:recovered] ? "RECOVERED" : "FAILED") : "SUCCESS"
        "#{step[:step_name]}: #{status} - #{step[:output] || step[:error]}"
      end.join("\n")
    end

    def sum_tokens(steps_completed)
      steps_completed.sum { |s| s[:tokens] || 0 }
    end

    def sum_duration(steps_completed)
      steps_completed.sum { |s| s[:duration_ms] || 0 }
    end
  end
end
