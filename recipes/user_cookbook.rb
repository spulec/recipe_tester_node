require 'rubygems'
require 'httparty'
require 'json'

user = node['username']
data_bag = data_bag_item('recipe-tester', 'config')

cookbook_name = data_bag['cookbook_name']
cookbook_url = data_bag['cookbook_url']
commit_reference = data_bag['cookbook_commit']
build_id = data_bag['build_id']


template "/var/chef/solo.rb" do
  source "solo.erb"
  owner user
  group user
end

template "/var/chef/node_attributes.json" do
  source "node_attributes.erb"
  owner user
  group user
  variables(
    :node_attributes => data_bag['node_attributes'])
end

git "Clone #{cookbook_name}" do
  user user
  group user
  repository cookbook_url
  reference commit_reference
  destination "/var/chef/cookbooks/#{cookbook_name}"
  action :checkout
end

template "/var/chef/cookbooks/#{cookbook_name}/Berksfile" do
  source "Berksfile.erb"
  owner user
  group user
  not_if {File.exists?("/var/chef/cookbooks/#{cookbook_name}/Berksfile")}
end

execute "Berksfile install" do
  # We install berkshelf to the chef ruby to avoid conflicts with the user cookbook
  command "/opt/chef/embedded/bin/berks install --path /var/chef/cookbooks >> /var/chef/user_cookbook.log"
  action :run
  # ignore_failure true
  cwd "/var/chef/cookbooks/#{cookbook_name}"
end

# After this point, the recipe_tester_node cookbook is no longer available

execute "Run chef-solo" do
  command "chef-solo -j /var/chef/node_attributes.json -c /var/chef/solo.rb -l debug >> /var/chef/user_cookbook.log 2>&1; echo $? > /var/chef/user_output.txt"
  action :run
  ignore_failure true
end

ruby_block "post_results" do
  block do
    file_data = File.read("/var/chef/user_output.txt").strip
    HTTParty.post('https://recipe-tester.com/internal_api/build_status',
        :body => {
                    :build_id => build_id,
                    :secret_key => data_bag['s3_secret_key'],
                    :status => file_data
                 })
  end
end

execute "shutdown" do
  command "sudo shutdown -h now"
  action :run
end
