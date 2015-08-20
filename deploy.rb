
require 'json'
require 'aws-sdk'
require 'optparse'


# verify that required environment variables have been set
assert_env_vars

# parse command line options
options = get_cmd_line_opts

# set global aws config with retry and some additional retries
Aws.config.update( region: options[:region] )

# create a global variables with our aws services.  this would not scale,
# but works for a small script like this
$cfm = Aws::CloudFormation::Client.new
$ec2 = Aws::EC2::Client.new

stack_name = options[:stack_name]

# create cloud-formation stack
puts "Creating cloud formation stack named #{stack_name}"
stack_output = create_stack( 
    stack_name, 
    cfm_template,
    options[:instance_type],    # optional parameter, could be nil.  default to cfm template default value
    options[:public_ip],
    options[:keypair_name] )
puts "Cloudformation stack id #{stack_output.stack_id} created"

# wait for the stack to be in a terminal state (either complete or failed)
stack_success = wait_for_terminal_state(stack_name)
raise "There was an error creating the cloudformation stack #{stack_name}" unless stack_success

# lookup the ec2 instance id from the cloudformation stack outputs
ec2_instance_id = get_ec2_instance_id(stack_name)
puts "Found EC2 instance with id #{ec2_instance_id}"

# wait for the ec2 instance to be in a ready state
wait_for_ec2_instance_ready_state(ec2_instance_id)

# install chef and run our mini cookbook
ec2_public_ip = get_ec2_instance_ip(stack_name)
bootstrap_instance(
  ec2_public_ip, 
  ec2_instance_id, 
  options[:keypair_file])

puts "Your EC2 public IP is: #{ec2_public_ip}"

BEGIN {

  ##
  # @return [String] content of the cloud formation template of this project
  def cfm_template
    template_path = File.expand_path('../cloudformation/deploy.json', __FILE__ )   
    raise "Unable to find cloud formation template at #{template_path}" unless File.exists? template_path
    IO.read(template_path)
  end

  ##
  # @param [String] What to name the cloud formation stack
  # @return [Aws::CloudFormation::Types::CreateStackOutput]
  def create_stack(stack_name, template, instance_type, public_ip, key_pair_name)

    params = {
        PublicIp:         public_ip,
        SshKeypairName:   key_pair_name
    }

    # add optional parameter instance_type if it has a non-nil value
    params[:InstanceType] = instance_type unless instance_type.nil?

    $cfm.create_stack({
      stack_name:       stack_name,
      template_body:    template,
      parameters:       params.map { |k,v|
        {
          parameter_key:    k,
          parameter_value:  v
        }
      },
      tags: [
        { key: 'author',    value: 'baysbenj@gmail.com' }
      ]
    })
  end

  ##
  # wait in a blocking loop until the specified cloud formation stack reaches a terminal state
  # @param [String] name of the cloudformation stack to poll
  # @return [TrueClass,FalseClass] true if the stack is in a successful state
  def wait_for_terminal_state(stack_name)
    while 1

      stack_state = get_stack_desc(stack_name).stack_status

      if stack_failed?(stack_state)
        return false
      elsif stack_successful?(stack_state)
        return true
      end

      puts "#{stack_name} is in state #{stack_state}.  Waiting for terminal state"
      # sleep 3 seconds and check again
      sleep 3
    end
    nil
  end

  ##
  # @param [String] name of the cloudformation stack
  # @return [Aws::Cloudformation::Types::DescribeStackOutput]
  def get_stack_desc(stack_name)
    stack_resp = $cfm.describe_stacks(
        stack_name:     stack_name
    )

    if stack_resp.nil?
      raise "Stack #{stack_name} was not found"
    elsif stack_resp.stacks.size != 1
      raise "More than one stack found matching name #{stack_name}"
    end

    stack_resp.stacks.first
  end

  ##
  # @param stack_state [String] current status of cloudformation stack
  # @return [TreuClass,FalseClass] True if the stack is in a failed state.  False otherwise
  def stack_failed?(stack_state)
    /_FAILED$/.match(stack_state) || stack_state=='ROLLBACK_COMPLETE'
  end

  ##
  # @param stack_state [String] current status of cloudformation stack
  # @return [TreuClass,FalseClass] True if the stack is in a successful complete state.  False otherwise
  def stack_successful?(stack_state)
    stack_state=='CREATE_COMPLETE'
  end

  ##
  # @param [String] Cloudformation stack name
  # @return [String] EC2 instance id of the form 'i-xxxxxxxx'
  def get_ec2_instance_id(stack_name)
    stack_desc = get_stack_desc(stack_name)
    stack_outputs = stack_desc.outputs.select { |o| o.output_key=='InstanceId' }
    stack_outputs.first.output_value
  end

  ##
  # @param [String] Cloudformation stack name
  # @return [String] EC2 public ip address
  def get_ec2_instance_ip(stack_name)
    stack_desc = get_stack_desc(stack_name)
    stack_outputs = stack_desc.outputs.select { |o| o.output_key=='PublicIp' }
    stack_outputs.first.output_value
  end

  ##
  # @param instance_id [String] EC2 instance id to poll
  def wait_for_ec2_instance_ready_state(instance_id)
    while 1
      resp = $ec2.describe_instance_status(
          instance_ids:           [ instance_id ],
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
      if system_status=='ok' && instance_status=='ok'
        return true
      end

      puts "Waiting for 'ok' status.  Current instance status = '#{instance_status}', system status = '#{system_status}'"
      sleep 3
      
    end
  end

  ##
  # assert that mandatory environment variables have been set by the user
  def assert_env_vars
    %w{AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY}.each do |var|
      raise "Environment variable #{var} must be set" unless ENV[var]
    end
    nil
  end

  ##
  # @return [Hash] Parsed command line options
  def get_cmd_line_opts
    options = {}

    OptionParser.new do |opts|

      opts.on('-k', '--key-pair-name <key_pair_name>', 'Name of AWS SSH Keypair') do |keypair_name|
        options[:keypair_name] = keypair_name
      end

      opts.on('-f', '--key-pair-file <ssh_key_pair_file>', 'Location of private AWS SSH Keypair') do |file|
        options[:keypair_file] = file
      end

      opts.on('-i', '--public-ip <public_ip>', 'Your public IP address') do |ip|
        options[:public_ip] = ip
      end

      opts.on('-r', '--region <aws_region>', 'AWS region') do |region|
        options[:region] = region
      end

      opts.on('-s', '--stack-name <stack_name>', 'Cloudformation stack name') do |stack_name|
        options[:stack_name] = stack_name
      end

      opts.on('-t', '--instance-type <aws_instance_type>', 'AWS instance type') do |instance_type|
        options[:instance_type] = instance_type
      end

    end.parse!

    [:keypair_name, :public_ip, :stack_name, :region].each do |arg| 
      raise "#{arg} is a required command line option" unless options.has_key? arg
    end

    options
  end

  ##
  # @param instance_ip [String] public ip address of the ec2 instance we're bootstrapping
  # @param instance_id [String] Name of the ec2 instance (used to name chef node)
  # @param ssh_key_file [String] optional file path to the ssh_key.  If not available, asssume ssh daemon.
  def bootstrap_instance(instance_ip, instance_id, ssh_key_file=nil)

    Dir.chdir('knife-solo') do
      solo_cmd = "knife solo bootstrap ec2-user@#{instance_ip} nodes/welcome_page.json"

      # optional, they might be using an ssh daemon
      unless ssh_key_file.nil?
        solo_cmd += " -i #{ssh_key_file}"
      end

      puts "Executing: (#{solo_cmd})"
      success = system solo_cmd
      exit unless success
    end
    
  end

}
