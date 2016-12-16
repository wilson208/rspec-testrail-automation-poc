require './sync_runner.rb'

def ensure_env_var_set(name, desc)
  raise "#{name} not set. #{desc}" if ENV[name].nil?
end

desc 'the new, rototiller way. This is for the README.md file.'
task :update_testrail do |t|
  ensure_env_var_set('RESULT_FILE', 'Required. JSON output file from beaker-rspec')
  ensure_env_var_set('TESTRAIL_USER', 'Required. Testrail Username')
  ensure_env_var_set('TESTRAIL_PASS', 'Required. Testrail Password')
  ensure_env_var_set('SUITE_NAME', 'Required. Test suite name within Modules & Forge project')
  ensure_env_var_set('GITHUB_REPO', 'Required. Repo name within the puppetlabs org')

  test_rail_base_url = 'https://testrail1-test.ops.puppetlabs.net'
  user               = ENV['TESTRAIL_USER']
  password           = ENV['TESTRAIL_PASS']
  rspec_log_path     = ENV['RESULT_FILE']
  suite_name         = ENV['SUITE_NAME']
  project_name       = 'Modules & Forge'
  github_branch_root = "https://github.com/puppetlabs/#{ENV['GITHUB_REPO']}/blob/master"

  runner = TestRail::SyncRunner.new(test_rail_base_url,
                                    user,
                                    password,
                                    rspec_log_path,
                                    project_name,
                                    suite_name,
                                    github_branch_root)

  runner.run
end