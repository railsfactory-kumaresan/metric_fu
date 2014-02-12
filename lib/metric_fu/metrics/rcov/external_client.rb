module MetricFu
  class RCovTestCoverageClient

    def initialize(coverage_file)
      @file_path = Pathname(coverage_file)
      @file_path.dirname.mkpath
    end

    def post_results(payload)
      mf_log "Saving coverage payload to #{@file_path}"
      dump(payload)
    end

    def load
      File.binread(@file_path)
    end

    def dump(payload)
      File.write(@file_path, payload)
    end

  end
end
