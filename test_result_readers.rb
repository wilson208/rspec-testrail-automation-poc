require 'json'

module TestRail
  class TestResultReaderBase
    attr_accessor :test_cases
    attr_accessor :test_files

    def initialize(output_path)
      raise "Test result output file not found at '#{output_path}'" unless File.exists?(output_path)
    end
  end

  class BeakerRspecResultReader < TestRail::TestResultReaderBase
    def initialize(output_path)
      super(output_path)
      load_output(output_path)
    end

    def load_output(output_path)
      json                   = File.open(output_path, 'rb').read
      unformatted_test_cases = JSON.parse json
      self.test_cases        = unformatted_test_cases['examples'].map do |test_case|
        {
            name:      test_case['full_description'],
            file_path: test_case['file_path'],
            line:      test_case['line_number'],
        }
      end

      self.test_files = self.test_cases.map { |test_case| test_case[:file_path].gsub(/^(\.\/)/, '') }
      self.test_files.uniq!
      puts self.test_files
    end

  end
end