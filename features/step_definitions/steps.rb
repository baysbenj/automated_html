

# note:  these methods should be much slimmer, ideally extracted out into support library code.  There
# is also some code duplication between this file and the deploy.rb script.  Again, support library code
# or perhaps a requiring a self-built gem would be ideal.

##
# assert that the status of the ec2 instance is 'ok'
Given(/^The EC2 instance is deployed$/) do
  ec2 = Aws::EC2::Client.new

  resp = ec2.describe_instance_status(
      instance_ids:           [ @ec2_instance_id ],
      include_all_instances:  true
  )

  if resp.nil?
    raise 'Unable to query for ec2 status'
  elsif resp.instance_statuses.size != 1
    raise "Expected exactly one EC2 instance with id #{instance_id}"
  end

  status_obj = resp.instance_statuses.first

  system_status = status_obj.system_status.status
  instance_status = status_obj.instance_status.status 

  expect( system_status ).to eq 'ok'
  expect( instance_status ).to eq 'ok'
  
end

##
# load the welcome page into a request object
When(/^The welcome page is loaded$/) do
  @http_response = RestClient::Request.new(
    method:   :get,
    url:      "http://#{@ec2_public_ip}"
  ).execute
end

##
# assert that the request object contains the expected text
Then(/^The page contains the text "([^"]+)"$/) do |expected_text|
  expect( @http_response ).to include(expected_text)
end

##
# assert that the request object has the expected http status code
Then(/^The HTTP status code is (\d+)$/) do |expected_status_code|
  expect( @http_response.code ).to eq expected_status_code.to_i
end
