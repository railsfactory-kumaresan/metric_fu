require 'spec_helper'
require 'simplecov'
require 'metric_fu/metrics/rcov/simplecov_formatter'

describe SimpleCov::Formatter::MetricFu do
  before do
    @rcov_file =  subject.coverage_file_path
    File.delete( @rcov_file ) if File.exists?( @rcov_file )

    @result = SimpleCov::Result.new(
      {
       FIXTURE.fixtures_path.join('coverage.rb').expand_path.to_s =>
        [1,1,1,1,nil,1,0,1,1,nil,0,1,1]
      }
    )

    # Set to default encoding
    Encoding.default_internal = nil if defined?(Encoding)
  end

  it "test_format" do
    SimpleCov::Formatter::MetricFu.new.format( @result )

    expect(File.exists?( @rcov_file )).to be_truthy
  end

  it "test_encoding" do
    # This is done in many rails environments
    Encoding.default_internal = 'UTF-8' if defined?(Encoding)

    SimpleCov::Formatter::MetricFu.new.format( @result )
  end

  it "test_create_content" do
    content = SimpleCov::Formatter::MetricFu::FormatLikeRCov.new(@result).format
    test = "\="*80

    expect(content).to match(/#{test}/)
    expect(content).to match(/!!     value \* value/)
  end
end
