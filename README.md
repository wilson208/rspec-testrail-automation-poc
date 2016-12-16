# Automated Testrail Data Population
A POC of automating population of testrail data from rspec json output file

## Usage
You will first have to tell rspec to use json formatted output to a file like so
<pre>
bundle exec rspec spec/acceptance <b>--format j --out output.json</b>
</pre>
After we get the rspec json output, we set a number of environment variables and run the rake task:
* RESULT_FILE - Required. JSON output file from beaker-rspec
* TESTRAIL_USER - Required. Testrail Username
* TESTRAIL_PASS - Required. Testrail Password
* SUITE_NAME - Required. Test suite name within Modules & Forge project
* GITHUB_REPO - Required. Repo name within the puppetlabs org.

<pre>
bundle install --path .bundle/gems
RESULT_FILE=results.json TESTRAIL_USER=ABC TESTRAIL_PASS=ABC SUITE_NAME='Automation Test' GITHUB_REPO=puppetlabs-vcsrepo bundle exec rake update_testrail
</pre>

## TestRail API Binding
### api_client.rb
I did not write this, the code in this class is pulled from [here](http://docs.gurock.com/testrail-api2/bindings-ruby).