module Tier0
  class DocumentationAnalyzer
    README_SECTIONS = %w[installation usage api examples contributing license].freeze
    
    def initialize(agent)
      @agent = agent
      @client = GithubClient.new
      parse_repo_url
    end
    
    def analyze
      readme = fetch_readme
      
      {
        readme_length: readme&.length || 0,
        has_badges: readme&.include?("![") || false,
        sections_found: detect_sections(readme),
        has_changelog: file_exists?("CHANGELOG.md") || file_exists?("HISTORY.md"),
        has_contributing: file_exists?("CONTRIBUTING.md"),
        has_license: file_exists?("LICENSE") || file_exists?("LICENSE.md"),
        has_docs_folder: folder_exists?("docs"),
        score: calculate_score(readme)
      }
    end
    
    private
    
    def fetch_readme
      %w[README.md readme.md README.rst README].each do |name|
        content = @client.contents(@owner, @repo, name)
        next unless content&.dig("content")
        return Base64.decode64(content["content"])
      end
      nil
    end
    
    def detect_sections(readme)
      return [] unless readme
      README_SECTIONS.select { |s| readme.downcase.include?("# #{s}") || readme.downcase.include?("## #{s}") }
    end
    
    def file_exists?(path)
      @client.contents(@owner, @repo, path).present?
    rescue
      false
    end
    
    def folder_exists?(path)
      content = @client.contents(@owner, @repo, path)
      content.is_a?(Array)
    rescue
      false
    end
    
    def calculate_score(readme)
      score = 0
      
      # README quality (max 40)
      if readme
        score += 10 if readme.length > 500
        score += 10 if readme.length > 2000
        score += 10 if readme.include?("![")  # badges
        score += 10 if detect_sections(readme).count >= 3
      end
      
      # Standard files (max 30)
      score += 10 if file_exists?("CHANGELOG.md") || file_exists?("HISTORY.md")
      score += 10 if file_exists?("CONTRIBUTING.md")
      score += 10 if file_exists?("LICENSE") || file_exists?("LICENSE.md")
      
      # Docs (max 30)
      score += 15 if folder_exists?("docs")
      score += 15 if folder_exists?("examples")
      
      [score, 100].min
    end
    
    def parse_repo_url
      match = @agent.repo_url.match(%r{github\.com/([^/]+)/([^/]+)})
      @owner, @repo = match[1], match[2].sub(/\.git$/, "") if match
    end
  end
end
