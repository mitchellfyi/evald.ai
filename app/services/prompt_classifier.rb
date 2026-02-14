# frozen_string_literal: true

class PromptClassifier
  TASK_CATEGORIES = {
    "coding" => {
      label: "Coding",
      subcategories: %w[debug generate refactor explain],
      keywords: %w[
        code debug fix bug error function class method variable type compile build
        test unit refactor api endpoint script program syntax parse implement
        deploy docker kubernetes ci cd pipeline git commit merge branch
        database sql query migration schema model controller
        javascript python ruby java typescript react vue angular node
        html css frontend backend fullstack algorithm regex
      ],
      patterns: [
        /writ\w*\s+(a\s+)?(code|function|script|program|class|method|test)/i,
        /debug\w*|fix\w*\s+(this|the|a|my)\s+(bug|error|issue|code)/i,
        /refactor\w*/i,
        /implement\w*/i,
        /\b(api|endpoint|route|controller|model|migration)\b/i,
        /\b(python|ruby|java|javascript|typescript|rust|go|c\+\+|swift)\b/i
      ]
    },
    "creative" => {
      label: "Creative",
      subcategories: %w[writing brainstorm roleplay],
      keywords: %w[
        write story poem essay blog article creative fiction novel
        brainstorm idea generate content narrative character plot
        roleplay pretend imagine scenario dialogue
        marketing copy headline slogan tagline brand
        email newsletter social media post tweet
      ],
      patterns: [
        /writ\w*\s+(a\s+)?(story|poem|essay|blog|article|email|letter)/i,
        /brainstorm\w*/i,
        /creative\w*\s+writ/i,
        /roleplay|pretend|imagine\s+you/i,
        /\b(story|poem|essay|blog|article|novel|fiction)\b/i
      ]
    },
    "reasoning" => {
      label: "Reasoning",
      subcategories: %w[math logic analysis],
      keywords: %w[
        math calculate solve equation formula proof theorem
        logic reason deduce analyze evaluate compare
        statistics probability data analysis pattern
        puzzle riddle problem solve think step
        decision pros cons tradeoff evaluate
      ],
      patterns: [
        /\b(calculate|compute|solve|prove|derive)\b/i,
        /\b(math|equation|formula|theorem|proof)\b/i,
        /step.by.step/i,
        /analyz\w*|evaluat\w*/i,
        /pros\s+and\s+cons/i,
        /\b(logic|logical|reasoning|deduc)\w*/i
      ]
    },
    "research" => {
      label: "Research",
      subcategories: %w[summarize compare fact_check],
      keywords: %w[
        research summarize summary explain overview
        compare comparison difference between versus vs
        fact check verify source cite reference
        review literature survey study paper
        find information about tell me what is
      ],
      patterns: [
        /summariz\w*/i,
        /compare\s+(and\s+contrast\s+)?.*\b(with|to|vs|versus)\b/i,
        /\bwhat\s+(is|are|was|were)\b/i,
        /\bexplain\s+(how|what|why|the)\b/i,
        /\b(research|survey|review|overview)\b/i,
        /fact.check|verify|source/i
      ]
    },
    "conversation" => {
      label: "Conversation",
      subcategories: %w[chat advice support],
      keywords: %w[
        help advice suggest recommend opinion
        chat talk discuss conversation
        support assist guide mentor coach
        feedback review comment
        personal career life relationship
      ],
      patterns: [
        /\b(help|advice|suggest|recommend)\s+me\b/i,
        /what\s+(should|would|do)\s+you\s+(think|suggest|recommend)/i,
        /\b(chat|talk|discuss)\b/i,
        /can\s+you\s+(help|assist|guide)/i,
        /\bhow\s+(should|do|can)\s+I\b/i
      ]
    },
    "multimodal" => {
      label: "Multimodal",
      subcategories: %w[vision audio documents],
      keywords: %w[
        image picture photo screenshot diagram chart graph
        video audio voice speech transcribe
        document pdf file upload scan ocr
        describe look see visual
      ],
      patterns: [
        /\b(image|picture|photo|screenshot|diagram)\b/i,
        /\b(video|audio|voice|speech|transcrib)\w*/i,
        /\b(document|pdf|file|upload|scan)\b/i,
        /\b(describe|analyze)\s+(this|the)\s+(image|photo|picture|document)/i
      ]
    },
    "agentic" => {
      label: "Agentic",
      subcategories: %w[multi_step tool_use autonomous],
      keywords: %w[
        automate automation workflow pipeline
        multi step sequence chain task
        tool use browse search web
        autonomous agent bot run execute
        scrape crawl extract monitor
        integrate connect api webhook
      ],
      patterns: [
        /\b(automat\w*|workflow|pipeline)\b/i,
        /\bmulti.?step\b/i,
        /\b(browse|search|scrape|crawl|monitor)\s+(the\s+)?(web|internet|site)/i,
        /\b(autonomous|agent|bot)\b/i,
        /\b(integrat\w*|connect\w*)\s+(with|to)\b/i
      ]
    }
  }.freeze

  SUBCATEGORY_HINTS = {
    "coding" => {
      "debug" => /debug|fix|error|bug|issue|broken|crash/i,
      "generate" => /write|create|build|make|generate|implement/i,
      "refactor" => /refactor|improve|clean|optimize|simplify/i,
      "explain" => /explain|what does|how does|why does|understand/i
    },
    "creative" => {
      "writing" => /write|draft|compose|essay|blog|article|story/i,
      "brainstorm" => /brainstorm|ideas|suggest|options|alternatives/i,
      "roleplay" => /roleplay|pretend|act as|you are|imagine you/i
    },
    "reasoning" => {
      "math" => /math|calculate|equation|formula|number|compute/i,
      "logic" => /logic|deduce|reason|infer|conclude/i,
      "analysis" => /analyze|evaluate|assess|compare|review/i
    },
    "research" => {
      "summarize" => /summarize|summary|overview|brief|recap/i,
      "compare" => /compare|difference|versus|vs|between/i,
      "fact_check" => /fact|verify|true|false|accurate|source/i
    },
    "conversation" => {
      "chat" => /chat|talk|hello|hi|hey/i,
      "advice" => /advice|suggest|recommend|should|opinion/i,
      "support" => /help|support|assist|guide|stuck/i
    },
    "multimodal" => {
      "vision" => /image|picture|photo|screenshot|see|look|visual/i,
      "audio" => /audio|voice|speech|sound|listen|transcrib/i,
      "documents" => /document|pdf|file|scan|upload/i
    },
    "agentic" => {
      "multi_step" => /step|sequence|chain|pipeline|workflow/i,
      "tool_use" => /tool|browse|search|web|api|connect/i,
      "autonomous" => /autonomous|automat|monitor|continuous|schedule/i
    }
  }.freeze

  Result = Struct.new(:category, :subcategory, :confidence, :scores, keyword_init: true)

  def self.classify(prompt)
    new.classify(prompt)
  end

  def classify(prompt)
    return Result.new(category: "conversation", subcategory: "chat", confidence: 0.0, scores: {}) if prompt.blank?

    scores = compute_scores(prompt)
    best_category, best_score = scores.max_by { |_, v| v }

    # Determine subcategory
    subcategory = detect_subcategory(prompt, best_category)

    # Normalize confidence to 0-1 range
    confidence = normalize_confidence(best_score, scores)

    Result.new(
      category: best_category,
      subcategory: subcategory,
      confidence: confidence.round(3),
      scores: scores.transform_values { |v| v.round(3) }
    )
  end

  private

  def compute_scores(prompt)
    normalized_prompt = prompt.downcase.strip

    TASK_CATEGORIES.each_with_object({}) do |(category, config), scores|
      keyword_score = keyword_match_score(normalized_prompt, config[:keywords])
      pattern_score = pattern_match_score(normalized_prompt, config[:patterns])

      # Weighted combination: patterns are more reliable than keywords
      scores[category] = (keyword_score * 0.4) + (pattern_score * 0.6)
    end
  end

  def keyword_match_score(prompt, keywords)
    return 0.0 if keywords.empty?

    matches = keywords.count { |kw| prompt.include?(kw) }
    # Diminishing returns - cap effective matches
    [matches.to_f / [keywords.size * 0.15, 1].max, 1.0].min
  end

  def pattern_match_score(prompt, patterns)
    return 0.0 if patterns.empty?

    matches = patterns.count { |pattern| prompt.match?(pattern) }
    [matches.to_f / [patterns.size * 0.3, 1].max, 1.0].min
  end

  def normalize_confidence(best_score, scores)
    return 0.0 if best_score.zero?

    sorted = scores.values.sort.reverse
    # Confidence is higher when the top score is well separated from the second
    if sorted.size > 1 && sorted[1] > 0
      separation = (sorted[0] - sorted[1]) / sorted[0]
      base_confidence = [best_score, 1.0].min
      (base_confidence * 0.6) + (separation * 0.4)
    else
      [best_score, 1.0].min
    end
  end

  def detect_subcategory(prompt, category)
    config = TASK_CATEGORIES[category]
    return config[:subcategories].first unless config

    normalized = prompt.downcase

    hints = SUBCATEGORY_HINTS[category]
    return config[:subcategories].first unless hints

    best_sub = hints.max_by { |_, pattern| normalized.scan(pattern).size }
    best_sub&.first || config[:subcategories].first
  end
end
