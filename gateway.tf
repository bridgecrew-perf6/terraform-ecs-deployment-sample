// create an isolated virtual private cloud
// When creating VPC we must provide a range of IPv4 addresses. 
// It’s the primary CIDR block for the VPC and this is the only required parameter.
resource "aws_vpc" "terraform_vpc" {
    cidr_block = "10.0.0.0/24"
    enable_dns_support   = true
    enable_dns_hostnames = true
    tags       = {
        Name = "Terraform VPC"
    }
}

// In order to allow communication between instances in our VPC and the internet 
// we need to create Internet gateway.
resource "aws_internet_gateway" "internet_gateway" {
    vpc_id = aws_vpc.terraform_vpc.id
}

// To create a subnet we need to provide VPC id and CIDR block. 
// Additionally we can specify availability zone, but it’s not required.
resource "aws_subnet" "pub_subnet" {
    vpc_id                  = aws_vpc.terraform_vpc.id
    cidr_block              = "10.0.0.0/16"
}

// Provides a resource to create a VPC routing table.
// Route table allows to set up rules that determine where network traffic from our 
// subnets is directed. Let’s create new, custom one, just to show how it can be used and 
// associated with subnets.
resource "aws_route_table" "public" {
    vpc_id = aws_vpc.terraform_vpc.id

    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.internet_gateway.id
    }
}

// Provides a resource to create an association between a route table and a subnet or a 
// route table and an internet gateway or virtual private gateway
resource "aws_route_table_association" "route_table_association" {
    subnet_id      = aws_subnet.pub_subnet.id
    route_table_id = aws_route_table.public.id
}

// Provides a security group resource.
// Security groups works like a firewalls for the instances (where ACL works like a 
// global firewall for the VPC).
// it allow all the traffic from the internet to and from the VPC we might set some rules
// to secure the instances themselves
resource "aws_security_group" "ecs_sg" {
    vpc_id      = aws_vpc.terraform_vpc.id

    ingress {
        from_port       = 22
        to_port         = 22
        protocol        = "tcp"
        cidr_blocks     = ["0.0.0.0/0"]
    }

    ingress {
        from_port       = 443
        to_port         = 443
        protocol        = "tcp"
        cidr_blocks     = ["0.0.0.0/0"]
    }

    egress {
        from_port       = 0
        to_port         = 65535
        protocol        = "tcp"
        cidr_blocks     = ["0.0.0.0/0"]
    }
}

// Generates an IAM policy document in JSON format for use with resources that 
// expect policy documents such as aws_iam_policy.
// Using this data source to generate policy documents is optional. 
// It is also valid to use literal JSON strings in your configuration or to use the 
// file interpolation function to read a raw JSON policy document from a file.
data "aws_iam_policy_document" "ecs_agent" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

//Provides an IAM role.
resource "aws_iam_role" "ecs_agent" {
  name               = "ecs-agent"
  assume_role_policy = data.aws_iam_policy_document.ecs_agent.json
}


resource "aws_iam_role_policy_attachment" "ecs_agent" {
  role       = "aws_iam_role.ecs_agent.name"
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}

resource "aws_iam_instance_profile" "ecs_agent" {
  name = "ecs-agent"
  role = aws_iam_role.ecs_agent.name
}


resource "aws_launch_configuration" "ecs_launch_config" {
    image_id             = "ami-094d4d00fd7462815"
    iam_instance_profile = aws_iam_instance_profile.ecs_agent.name
    security_groups      = [aws_security_group.ecs_sg.id]
    user_data            = "#!/bin/bash\necho ECS_CLUSTER=my-cluster >> /etc/ecs/ecs.config"
    instance_type        = "t2.micro"
}

resource "aws_autoscaling_group" "failure_analysis_ecs_asg" {
    name                      = "asg"
    vpc_zone_identifier       = [aws_subnet.pub_subnet.id]
    launch_configuration      = aws_launch_configuration.ecs_launch_config.name

    desired_capacity          = 2
    min_size                  = 1
    max_size                  = 10
    health_check_grace_period = 300
    health_check_type         = "EC2"
}