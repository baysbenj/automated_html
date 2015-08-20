
Automated Html
===================

The deploy.rb script will create an ec2 instance and deploy nginx to it using knife-solo.

1. Cloudformation is used to deploy the ec2 instance.
2. knife-api (a third party gem is used) to upload local cookbooks and exeecute chef-solo.


# Install Instructions

Bundler is used to control the ruby dependencies of this project.  If you have not already installed bundler.

    gem install bundler

Once bundler is available, you can install the gem dependencies by executing from the project root.

    bundle install

AWS credentials are required to use cloudformation.  Please ensure that environment variables are set in your session.

    export AWS_ACCESS_KEY_ID=xxxxxxxxxxxxxxxxxxxxx
    export AWS_SECRET_ACCESS_KEY=xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx


# Run the script

The script requires the following options:

1. ssh\_keypair\_name:  The name of an available ssh keypair in your aws account.  You must have the private key available.
2. private\_ssh\_key: Optional path to your private ssh key.  If your ssh key is added to your ssh agent, then this option can be omitted.
3. your\_public\_ip:  Your public ip address.  This is the address that you appear to the internet as.  To retrieve this, you can google "what is my ip".  This is used to setup port 22 firewall rule.
4. aws\_region: Which aws region you would like to deploy to.  Example 'us-east-1'.  Only US regions are supported.
5. instance\_type:  Which AWS instance type you'd like to use.  Only free and small instances are supported, such as t1.micro, m1.small, m3.small, etc.  t2 is not supported, as it is only available in VPC and this script uses EC2 classic.
6. stack\_name: What to name your aws cloudformation stack.  Must be unique to among any other stacks you have deployed.

    bundle exec ruby deploy.rb -k <ssh_keypair_name> [-f <private_ssh_key>] -i <your_public_ip> -r <aws_region> -t <instance_type> -s <stack_name>

Example usage:

    bundle exec ruby deploy.rb -k my_keypair -i 173.74.63.254 -r us-east-1 -t t1.micro -s test1
  
