# frozen_string_literal: true

module Agent
  class Skills
    DIR = Rails.root.join("app/agent_skills")
    Entry = Struct.new(:name, :description, :body, :digest, keyword_init: true)

    class << self
      def all
        Dir.glob(DIR.join("*.md")).sort.map { |path| load_file(path) }
      end

      def find(name)
        all.find { |skill| skill.name == name }
      end

      private

      def load_file(path)
        body = File.read(path)
        metadata = frontmatter(body)
        name = metadata["name"].presence || File.basename(path, ".md")
        description = metadata["description"].to_s
        Entry.new(
          name: name,
          description: description,
          body: body,
          digest: "sha256:#{Digest::SHA256.hexdigest(body)}"
        )
      end

      def frontmatter(body)
        text = body.force_encoding(Encoding::UTF_8)
        return {} unless text.start_with?("---")

        closing = text.index("\n---", 3)
        return {} unless closing

        YAML.safe_load(text[4...closing]) || {}
      rescue Psych::SyntaxError
        {}
      end
    end
  end
end
