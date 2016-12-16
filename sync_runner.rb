require './api_client.rb'
require './test_result_readers.rb'

module TestRail
  class SyncRunner
    attr_accessor :rspec_log_path
    attr_accessor :github_branch_root
    attr_accessor :project_id
    attr_accessor :suite_id
    attr_accessor :test_cases_section_id
    attr_accessor :api_client
    attr_accessor :test_result_reader
    attr_accessor :sub_sections

    def initialize(test_rail_base_url, user, password, rspec_log_path, project_name, suite_name, github_branch_root)
      # Setup the client
      self.api_client            = TestRail::APIClient.new(test_rail_base_url)
      self.api_client.user       = user
      self.api_client.password   = password

      # Load the test cases
      self.test_result_reader    = TestRail::BeakerRspecResultReader.new(rspec_log_path)

      # Find the project id, suite id and test cases section id
      self.project_id            = get_project_id_from_name(project_name)
      self.suite_id              = get_project_suite_id_from_name(suite_name)
      self.test_cases_section_id = get_suite_test_cases_section_id

      # Load sub sections as they will be used later for adding/updating/removing test cases
      self.sub_sections = get_subsections

      self.rspec_log_path    = rspec_log_path
      self.github_branch_root= github_branch_root
    end

    def run
      test_cases_to_add = get_test_cases_to_add_to_test_rail
      puts "To Add: #{test_cases_to_add.size} Test Cases"
      test_cases_to_add.each do |tc|
        add_test_case_to_test_rail(tc[:name], tc[:file_path], tc[:line])
      end

      # test_cases_to_remove = get_test_rail_cases_to_remove
      # puts "To Remove: #{test_cases_to_remove.size} Test Cases"
      # test_cases_to_remove.each do |tc|
      #   delete_test_case_in_test_rail(tc[:id])
      # end
      #
      # test_cases_to_update = get_test_rail_cases_to_update
      # puts "To Update: #{test_cases_to_update.size} Test Cases"
      # test_cases_to_update.each do |tc|
      #   update_test_case_to_test_rail(tc[:id], tc[:file_path], tc[:line])
      # end
    end

    private

    def add_test_case_to_test_rail(name, file_path, line_number)
      file_path.gsub!(/^(\.\/)/, '')
      section = get_sub_section(file_path)
      data = {
          title: name,
          custom_test_status: 2,
          custom_auto_test_link: "#{github_branch_root}/#{file_path}#L#{line_number}",
          description: 'This has been added automatically.'
      }

      res = api_client.send_post("add_case/#{section[:id]}", data)
      puts "Test Case Added - Section: #{section[:id]} - #{file_path}"
      puts " - #{res['id']}: #{name}"
    end

    def update_test_case_to_test_rail(id, file_path, line_number)
      raise 'Not yet implemented'
    end

    def delete_test_case_in_test_rail(id)
      raise 'Not yet implemented'
    end

    def get_test_cases_to_add_to_test_rail
      existing_test_cases = get_suite_test_cases
      self.test_result_reader.test_cases.select do |result_tc|
        section_id = get_sub_section(result_tc[:file_path])[:id]

        !existing_test_cases.any? do |test_rail_tc|
          name_same = test_rail_tc[:name].eql?(result_tc[:name])
          section_same = test_rail_tc[:section_id] == section_id
          name_same == true && section_same == true
        end
      end
    end

    def get_test_rail_cases_to_remove
      test_result_names = self.test_result_reader.test_cases.map { |test_case| test_case[:name] }
      get_suite_test_cases.select { |test_case| !test_result_names.include?(test_case[:name]) }
    end

    def get_test_rail_cases_to_update
      get_suite_test_cases.select do |test_rail_test_case|
        !self.test_result_reader.test_cases.select do |result_test_case|
          test_rail_test_case[:name] == result_test_case[:name] &&
              !(test_rail_test_case[:line] == result_test_case[:line] &&
                  test_rail_test_case[:file_path] == result_test_case[:file_path])
        end
      end
    end

    def get_sub_section(file_path)
      file_path.gsub!(/^(\.\/)/, '')
      matching_sections = self.sub_sections.select {|section| section[:name] == file_path}
      return create_sub_section(file_path) if matching_sections.size == 0
      return matching_sections[0] if matching_sections.size == 1
      raise "Error getting sub section for file path '#{file_path}'"
    end

    def create_sub_section(file_path)
      file_path.gsub!(/^(\.\/)/, '')
      matching_sections = self.sub_sections.select {|section| section[:name] == file_path}
      raise 'Cannot add section for file name which already exists' if(matching_sections.size != 0)

      data = {
          name: file_path,
          parent_id: self.test_cases_section_id,
          suite_id: self.suite_id,
          description: 'Auto-generated from module test results'
      }
      res = api_client.send_post("add_section/#{self.project_id}", data)

      res = {
          id: res['id'],
          name: res['name']
      }
      self.sub_sections.push(res)
      res
    end

    def get_subsections
      sub_sections = api_client.send_get("get_sections/#{self.project_id}&suite_id=#{self.suite_id}").select {|section| section['parent_id'] == self.test_cases_section_id }
      sub_sections.map{ |section| {id: section['id'], name: section['name']}}
    end

    def get_suite_test_cases_section_id
      sections          = api_client.send_get("get_sections/#{self.project_id}&suite_id=#{self.suite_id}")
      sections_matching = sections.select { |sec| sec['name'] == 'Test Cases' && sec['parent_id'].nil? }
      return sections_matching[0]['id'] if sections_matching.size == 1
      raise "Section with name 'Test Cases' not found in suite with ID '#{suite_id}'"
    end

    def get_suite_test_cases
      api_client.send_get("get_cases/#{project_id}&suite_id=#{suite_id}").map do |test_case|
        file_path = test_case['custom_auto_test_link'][/#{Regexp.escape(self.github_branch_root)}\/(.*)#L(\d+)/i, 0]
        line      = test_case['custom_auto_test_link'][/#{Regexp.escape(self.github_branch_root)}\/(.*)#L(\d+)/i, 1]
        {
            id:        test_case['id'],
            section_id: test_case['section_id'],
            name:      test_case['title'],
            file_path: file_path,
            line:      line
        }
      end
    end

    def get_project_id_from_name(project_name)
      projects               = api_client.send_get('get_projects')
      projects_matching_name = projects.select { |proj| proj['name'] == project_name }
      return projects_matching_name[0]['id'] if projects_matching_name.size == 1
      raise "Project with name '#{project_name}' not found (or duplicate found)"
    end

    def get_project_suite_id_from_name(suite_name)
      suites               = api_client.send_get("get_suites/#{self.project_id}")
      suites_matching_name = suites.select { |suite| suite['name'] == suite_name }
      return suites_matching_name[0]['id'] if suites_matching_name.size == 1
      raise "Suite with name '#{suite_name}' not found in project with ID '#{self.project_id}'"
    end
  end
end
