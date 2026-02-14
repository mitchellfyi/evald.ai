# frozen_string_literal: true

class AgentRouter
  # Maps prompt classifier categories to agent model categories/domains
  CATEGORY_TO_AGENT_FIELDS = {
    "coding" => { categories: %w[coding], domains: %w[coding] },
    "creative" => { categories: %w[general assistant], domains: [] },
    "reasoning" => { categories: %w[research general], domains: %w[research] },
    "research" => { categories: %w[research], domains: %w[research] },
    "conversation" => { categories: %w[assistant general], domains: [] },
    "multimodal" => { categories: %w[general assistant], domains: [] },
    "agentic" => { categories: %w[workflow coding], domains: %w[workflow coding] }
  }.freeze

  # Scoring weights
  WEIGHTS = {
    task_fit: 0.40,
    performance: 0.30,
    description_match: 0.20,
    recency: 0.10
  }.freeze

  AgentMatch = Struct.new(:agent, :score, :reasons, :task_fit, :category, keyword_init: true)

  def self.route(prompt, limit: 5)
    new.route(prompt, limit: limit)
  end

  def route(prompt, limit: 5)
    return [] if prompt.blank?

    # Normalize limit to a safe range
    limit = [limit.to_i, 1].max
    limit = [limit, 20].min

    # 1. Classify the prompt
    classification = PromptClassifier.classify(prompt)

    # 2. Find candidate agents
    candidates = find_candidates(classification.category)

    # 3. Score and rank
    ranked = candidates.map do |agent|
      score_agent(agent, classification, prompt)
    end

    ranked.sort_by { |m| -m.score }.first(limit)
  end

  private

  def find_candidates(category)
    mapping = CATEGORY_TO_AGENT_FIELDS[category] || { categories: %w[general], domains: [] }

    agents = Agent.published

    # Find agents matching the category or domain
    category_agents = agents.where(category: mapping[:categories])

    if mapping[:domains].present?
      domain_agents = agents.where("target_domains && ARRAY[?]::varchar[]", mapping[:domains])
      # Also include agents with domain scores > 0
      domain_score_agents = mapping[:domains].reduce(agents.none) do |scope, domain|
        column = Agent::DOMAIN_SCORE_COLUMNS[domain]
        next scope unless column

        scope.or(agents.where(Agent.arel_table[column].gt(0)))
      end

      # Combine: category match OR domain match, in a single relation
      category_agents.or(domain_agents).or(domain_score_agents)
        .distinct.order(score: :desc).limit(20)
    else
      category_agents.order(score: :desc).limit(20)
    end
  end

  def score_agent(agent, classification, prompt)
    task_fit = compute_task_fit(agent, classification)
    performance = compute_performance(agent, classification.category)
    desc_match = compute_description_match(agent, prompt)
    recency = compute_recency(agent)

    total = (task_fit * WEIGHTS[:task_fit]) +
            (performance * WEIGHTS[:performance]) +
            (desc_match * WEIGHTS[:description_match]) +
            (recency * WEIGHTS[:recency])

    # Normalize to 0-100 percentage
    match_pct = (total * 100).round(1)

    reasons = build_reasons(agent, classification, task_fit, performance)

    AgentMatch.new(
      agent: agent,
      score: match_pct,
      reasons: reasons,
      task_fit: task_fit,
      category: classification.category
    )
  end

  def compute_task_fit(agent, classification)
    mapping = CATEGORY_TO_AGENT_FIELDS[classification.category] || { categories: %w[general], domains: [] }

    score = 0.0

    # Category match
    if mapping[:categories].include?(agent.category)
      score += 0.6
    end

    # Domain match
    if mapping[:domains].present?
      agent_domains = agent.target_domains || []
      if (mapping[:domains] & agent_domains).any?
        score += 0.3
      end

      # Domain score match
      mapping[:domains].each do |domain|
        next unless Agent::DOMAINS.include?(domain)

        domain_score = agent.send("#{domain}_score")
        if domain_score.present? && domain_score > 0
          score += 0.1
          break
        end
      end
    else
      # No specific domain requirement - general task fit
      score += 0.2 if agent.category.present?
    end

    [score, 1.0].min
  end

  def compute_performance(agent, category)
    # Use the agent's overall score normalized to 0-1
    overall = agent.decayed_score || 0
    normalized_overall = overall.to_f / 100.0

    # Check for domain-specific score
    mapping = CATEGORY_TO_AGENT_FIELDS[category] || { domains: [] }
    domain_score = nil

    mapping[:domains]&.each do |domain|
      next unless Agent::DOMAINS.include?(domain)

      ds = agent.send("#{domain}_score")
      if ds.present? && ds > 0
        domain_score = ds.to_f / 100.0
        break
      end
    end

    # Prefer domain-specific score if available
    if domain_score
      (domain_score * 0.7) + (normalized_overall * 0.3)
    else
      normalized_overall
    end
  end

  def compute_description_match(agent, prompt)
    return 0.0 if agent.description.blank? || prompt.blank?

    # Simple word overlap scoring
    prompt_words = prompt.downcase.split(/\W+/).reject { |w| w.length < 3 }.uniq
    desc_words = agent.description.downcase.split(/\W+/).reject { |w| w.length < 3 }.uniq

    return 0.0 if prompt_words.empty? || desc_words.empty?

    overlap = (prompt_words & desc_words).size
    [overlap.to_f / [prompt_words.size, 5].max, 1.0].min
  end

  def compute_recency(agent)
    return 0.0 unless agent.last_verified_at

    days_ago = (Time.current - agent.last_verified_at) / 1.day

    if days_ago < 7
      1.0
    elsif days_ago < 30
      0.8
    elsif days_ago < 90
      0.5
    else
      0.2
    end
  end

  def build_reasons(agent, classification, task_fit, performance)
    reasons = []

    if task_fit >= 0.8
      reasons << "Strong #{classification.category} capability"
    elsif task_fit >= 0.5
      reasons << "#{classification.category.capitalize} support"
    end

    if agent.primary_domain == classification.category
      reasons << "Primary domain: #{classification.category}"
    end

    if performance >= 0.8
      reasons << "High Evald Score (#{agent.decayed_score&.round || 'N/A'})"
    elsif performance >= 0.5
      reasons << "Good performance track record"
    end

    if agent.verified?
      reasons << "Verified builder"
    end

    reasons << "Category: #{agent.category}" if reasons.empty?
    reasons
  end
end
