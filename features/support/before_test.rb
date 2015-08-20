
require 'aws-sdk'
require 'rest-client'

# object to hold the http request (so that we can later assert content/codes, etc)
@http_response = nil

# [String] to hold the AWS EC2 instance id (e.g. 'i-xxxxxxxx')
@ec2_instance_id = nil

# [String] to hold the AWS EC2 public IP address
@ec2_public_ip = nil

Before do |scenario|
  reset_instance_vars
end

def reset_instance_vars
  @http_response = nil

  cfm_stack_name = ENV['STACK_NAME']
  raise "Environmant Variable 'STACK_NAME' must be set to run cucumber tests" unless cfm_stack_name

  load_aws_vars(cfm_stack_name)  
end

def load_aws_vars(stack_name)
  cfm = Aws::CloudFormation::Client.new
  ec2 = Aws::EC2::Client.new

  stack_resp = cfm.describe_stacks(stack_name: stack_name)

  if stack_resp.nil?
    raise "Stack #{stack_name} was not found"
  elsif stack_resp.stacks.size != 1
    raise "More than one stack found matching name #{stack_name}"
  end

  stack = stack_resp.stacks.first
  stack_outputs = stack.outputs

  @ec2_instance_id = stack_outputs.select { |o| o.output_key=='InstanceId' }.first.output_value
  @ec2_public_ip = stack_outputs.select { |o| o.output_key=='PublicIp' }.first.output_value

  nil
end
