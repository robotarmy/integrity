module Integrity
  class Builder
    def self.build(b)
      new(b).build
    end

    def initialize(build)
      @build  = build
      @status = false
      @output = ""
    end

    def build
      start
      run
      complete
    end

    def start
      Integrity.log "Started building #{@build.project.uri} at #{commit}"

      repo.checkout

      metadata = repo.metadata

      @build.update(
        :started_at => Time.now,
        :commit     => {
          :identifier   => metadata["id"],
          :message      => metadata["message"],
          :author       => metadata["author"],
          :committed_at => metadata["timestamp"]
        }
      )
    end

    def complete
      Integrity.log "Build #{commit} exited with #{@status} got:\n #{@output}"

      @build.update!(
        :completed_at => Time.now,
        :successful   => @status,
        :output       => @output
      )

      @build.project.enabled_notifiers.each { |n| n.notify_of_build(@build) }
    end

    def run
      @dir = repo.directory
      cmd = normalize(@build.project.command)
      IO.popen(cmd, "r") { |io| @output = io.read }
      @status = $?.success?
    end

    def repo
      @repo ||= Repository.new(
        @build.id, @build.project.uri, @build.project.branch, commit
      )
    end

    def commit
      @build.commit.identifier
    end

    def normalize(cmd)
      if @dir
        "(#{pre_bundler_env} && cd #{@dir} && #{cmd} 2>&1)"
      else
        "(#{pre_bundler_env} && #{cmd} 2>&1)"
      end
    end

    private
      def pre_bundler_env
        "RUBYOPT=#{pre_bundler_rubyopt} PATH=#{pre_bundler_path}"
      end

      def pre_bundler_path
        ENV['PATH'] && ENV["PATH"].split(":").reject { |path| path.include?("bundle") }.join(":")
      end

      def pre_bundler_rubyopt
        ENV['RUBYOPT'] && ENV["RUBYOPT"].split.reject { |opt| opt.include?("bundle") }.join(" ")
      end
  end
end
