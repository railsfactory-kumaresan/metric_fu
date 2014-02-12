module MetricFu
  class RCovFormatCoverage
    NEW_FILE_MARKER = /^={80}$/.freeze

    def initialize(rcov_text)
      fail "no rcov text" if rcov_text.nil?
      @rcov_text = rcov_text
    end

    class Line
      attr_accessor :content, :was_run

      def initialize(content, was_run)
        @content = content
        @was_run = was_run
      end

      def to_h
        {:content => @content, :was_run => @was_run}
      end
    end

    def to_h
      rcov_text = @rcov_text.split(NEW_FILE_MARKER)

      rcov_text.shift # Throw away the first entry - it's the execution time etc.

      files = assemble_files(rcov_text)


      TestCoverage.new(files).to_h
    end

    private

    def assemble_files(rcov_text)
      files = {}
      rcov_text.each_slice(2) {|out| files[out.first.strip] = out.last}
      files.each_pair {|fname, content| files[fname] = content.split("\n") }
      files.each_pair do |fname, content|
        content.map! do |raw_line|
          covered_line = raw_line.match(/^!!/).nil?
          Line.new(raw_line[3..-1], covered_line).to_h
        end
        content.reject! {|line| line[:content].to_s == '' }
        files[fname] = {:lines => content}
      end
      files
    end

    class TestCoverage
      def initialize(filename_content)
        @files = filename_content
        @global_total_lines = 0
        @global_total_lines_run = 0
      end

      def to_h
        @test_coverage ||= begin
          add_coverage_percentage(@files)
          add_method_data(@files)
          add_global_percent_run(@files, @global_total_lines, @global_total_lines_run)
          @files
        end
      end

      private
      # TODO: remove multiple side effects
      #   sets global ivars and
      #   modifies the param passed in
      def add_coverage_percentage(files)
        files.each_pair do |fname, content|
          lines = content[:lines]
          lines_run = lines.count {|line| line[:was_run] }
          total_lines = lines.length
          integer_percent = ::MetricFu::Calculate.integer_percent(lines_run, total_lines)

          files[fname][:percent_run] = integer_percent
          @global_total_lines_run += lines_run
          @global_total_lines += total_lines
        end
      end

      def add_global_percent_run(test_coverage, total_lines, total_lines_run)
        percentage = (total_lines_run.to_f / total_lines.to_f) * 100
        test_coverage.update({
          :global_percent_run => round_to_tenths(percentage)
        })
      end

      def add_method_data(test_coverage)
        test_coverage.each_pair do |file_path, info|
          file_contents = ""
          coverage = []

          info[:lines].each_with_index do |line, index|
            file_contents << "#{line[:content]}\n"
            coverage << line[:was_run]
          end

          begin
            line_numbers = MetricFu::LineNumbers.new(file_contents)
          rescue StandardError => e
            raise e unless e.message =~ /you shouldn't be able to get here/
            mf_log "ruby_parser blew up while trying to parse #{file_path}. You won't have method level TestCoverage information for this file."
            next
          end

          method_coverage_map = {}
          coverage.each_with_index do |covered, index|
            line_number = index + 1
            if line_numbers.in_method?(line_number)
              method_name = line_numbers.method_at_line(line_number)
              method_coverage_map[method_name] ||= {}
              method_coverage_map[method_name][:total] ||= 0
              method_coverage_map[method_name][:total] += 1
              method_coverage_map[method_name][:uncovered] ||= 0
              method_coverage_map[method_name][:uncovered] += 1 if !covered
            end
          end

          test_coverage[file_path][:methods] = {}

          method_coverage_map.each do |method_name, coverage_data|
            test_coverage[file_path][:methods][method_name] = (coverage_data[:uncovered] / coverage_data[:total].to_f) * 100.0
          end

        end
      end

      def round_to_tenths(decimal)
        decimal = 0.0 if decimal.to_s.eql?('NaN')
        (decimal * 10).round / 10.0
      end


    end

  end
end
