# ----------------------------------------------------------------
# EC2 Module Test Suite
#
# Tests the EC2 Auto Scaling Group module for security defaults,
# conditional logic, transformations, and complex configurations
# that could break. Does not test simple pass-through variables.
# ----------------------------------------------------------------

variables {
  # Mock networking resources
  subnet_ids             = ["subnet-11111111", "subnet-22222222", "subnet-33333333"]
  security_group_ids     = ["sg-12345678"]
  test_ami_id            = "ami-12345678"
  test_instance_profile  = "test-instance-profile"
  test_target_group_arns = ["arn:aws:elasticloadbalancing:us-east-1:123456789012:targetgroup/test/1234567890abcdef"]
}

# ----------------------------------------------------------------
# Security defaults are enforced
# Expected: IMDSv2 required, EBS encrypted, monitoring enabled
# ----------------------------------------------------------------
run "security_defaults" {
  command = plan

  variables {
    name               = "test-asg"
    ami_id             = var.test_ami_id
    instance_type      = "t3.medium"
    subnet_ids         = var.subnet_ids
    security_group_ids = var.security_group_ids
    desired_capacity   = 1
    min_size           = 1
    max_size           = 2
  }

  # Assert IMDSv2 is REQUIRED (not optional)
  assert {
    condition     = aws_launch_template.this.metadata_options[0].http_tokens == "required"
    error_message = "IMDSv2 must be required for security"
  }

  # Assert IMDS hop limit is 1 to prevent SSRF
  assert {
    condition     = tonumber(aws_launch_template.this.metadata_options[0].http_put_response_hop_limit) == 1
    error_message = "IMDS hop limit should be 1 to prevent SSRF attacks"
  }

  # Assert EBS encryption is ENABLED by default
  assert {
    condition     = tobool(aws_launch_template.this.block_device_mappings[0].ebs[0].encrypted) == true
    error_message = "Root volume must be encrypted"
  }

  # Assert monitoring is ENABLED by default
  assert {
    condition     = tobool(aws_launch_template.this.monitoring[0].enabled) == true
    error_message = "CloudWatch detailed monitoring must be enabled"
  }

  # Assert delete on termination is TRUE
  assert {
    condition     = tobool(aws_launch_template.this.block_device_mappings[0].ebs[0].delete_on_termination) == true
    error_message = "Root volume should be deleted on termination"
  }
}

# ----------------------------------------------------------------
# ASG name transformation
# Expected: Name gets "-asg" suffix
# ----------------------------------------------------------------
run "name_suffix_transform" {
  command = plan

  variables {
    name               = "my-app"
    ami_id             = var.test_ami_id
    instance_type      = "t3.micro"
    subnet_ids         = var.subnet_ids
    security_group_ids = var.security_group_ids
    desired_capacity   = 1
    min_size           = 1
    max_size           = 1
  }

  # Assert ASG name gets suffix
  assert {
    condition     = aws_autoscaling_group.this.name == "my-app-asg"
    error_message = "ASG name should have -asg suffix"
  }

  # Launch template name uses name_prefix so is unknown during plan
  # This is expected behavior and not tested
}

# ----------------------------------------------------------------
# User data is base64 encoded
# Expected: Plain text input is transformed to base64
# ----------------------------------------------------------------
run "user_data_encoding" {
  command = plan

  variables {
    name               = "test-asg"
    ami_id             = var.test_ami_id
    instance_type      = "t3.micro"
    subnet_ids         = var.subnet_ids
    security_group_ids = var.security_group_ids
    user_data          = "#!/bin/bash\necho 'test'"
    desired_capacity   = 1
    min_size           = 1
    max_size           = 1
  }

  # Assert user data is present and encoded
  assert {
    condition     = aws_launch_template.this.user_data != null
    error_message = "User data should be base64 encoded when provided"
  }

  # User data should NOT be the raw string (it's base64 encoded)
  assert {
    condition     = aws_launch_template.this.user_data != "#!/bin/bash\necho 'test'"
    error_message = "User data should be base64 encoded, not plain text"
  }
}

# ----------------------------------------------------------------
# Launch template uses $Latest version
# Expected: ASG always uses latest template version
# ----------------------------------------------------------------
run "launch_template_versioning" {
  command = plan

  variables {
    name               = "test-asg"
    ami_id             = var.test_ami_id
    instance_type      = "t3.micro"
    subnet_ids         = var.subnet_ids
    security_group_ids = var.security_group_ids
    desired_capacity   = 1
    min_size           = 1
    max_size           = 1
  }

  # Assert ASG uses $Latest version
  assert {
    condition     = aws_autoscaling_group.this.launch_template[0].version == "$Latest"
    error_message = "ASG must use $Latest launch template version for updates"
  }
}

# ----------------------------------------------------------------
# Health check type affects ASG behavior
# Expected: ELB health checks when target groups attached
# ----------------------------------------------------------------
run "health_check_conditional" {
  command = plan

  variables {
    name               = "test-asg-elb"
    ami_id             = var.test_ami_id
    instance_type      = "t3.micro"
    subnet_ids         = var.subnet_ids
    security_group_ids = var.security_group_ids
    target_group_arns  = var.test_target_group_arns
    health_check_type  = "ELB"
    desired_capacity   = 1
    min_size           = 1
    max_size           = 2
  }

  # Assert health check type changes from default EC2 to ELB
  assert {
    condition     = aws_autoscaling_group.this.health_check_type == "ELB"
    error_message = "Health check type should be configurable to ELB"
  }

  # Assert target groups are attached
  assert {
    condition     = length(aws_autoscaling_group.this.target_group_arns) > 0
    error_message = "Target groups should be attached when provided"
  }
}

# ----------------------------------------------------------------
# CloudWatch metrics are automatically enabled
# Expected: Key ASG metrics are collected
# ----------------------------------------------------------------
run "cloudwatch_metrics_enabled" {
  command = plan

  variables {
    name               = "test-asg"
    ami_id             = var.test_ami_id
    instance_type      = "t3.micro"
    subnet_ids         = var.subnet_ids
    security_group_ids = var.security_group_ids
    desired_capacity   = 1
    min_size           = 1
    max_size           = 1
  }

  # Assert GroupDesiredCapacity metric is enabled
  assert {
    condition     = contains(aws_autoscaling_group.this.enabled_metrics, "GroupDesiredCapacity")
    error_message = "GroupDesiredCapacity metric should be enabled"
  }

  # Assert GroupInServiceInstances metric is enabled
  assert {
    condition     = contains(aws_autoscaling_group.this.enabled_metrics, "GroupInServiceInstances")
    error_message = "GroupInServiceInstances metric should be enabled"
  }

  # Assert GroupTotalInstances metric is enabled
  assert {
    condition     = contains(aws_autoscaling_group.this.enabled_metrics, "GroupTotalInstances")
    error_message = "GroupTotalInstances metric should be enabled"
  }
}

# ----------------------------------------------------------------
# Tag specifications are created for resources
# Expected: Tags propagate to instances and volumes
# ----------------------------------------------------------------
run "tag_propagation" {
  command = plan

  variables {
    name               = "test-asg"
    ami_id             = var.test_ami_id
    instance_type      = "t3.micro"
    subnet_ids         = var.subnet_ids
    security_group_ids = var.security_group_ids
    desired_capacity   = 1
    min_size           = 1
    max_size           = 1
    tags = {
      Environment = "test"
    }
  }

  # Assert instance tag specification exists
  assert {
    condition = length([
      for spec in aws_launch_template.this.tag_specifications : spec
      if spec.resource_type == "instance"
    ]) == 1
    error_message = "Launch template must include tag specifications for instances"
  }

  # Assert volume tag specification exists
  assert {
    condition = length([
      for spec in aws_launch_template.this.tag_specifications : spec
      if spec.resource_type == "volume"
    ]) == 1
    error_message = "Launch template must include tag specifications for volumes"
  }
}

# ----------------------------------------------------------------
# IAM instance profile is optional
# Expected: Launch template works with and without profile
# ----------------------------------------------------------------
run "iam_profile_optional" {
  command = plan

  variables {
    name                 = "test-asg-iam"
    ami_id               = var.test_ami_id
    instance_type        = "t3.micro"
    subnet_ids           = var.subnet_ids
    security_group_ids   = var.security_group_ids
    iam_instance_profile = var.test_instance_profile
    desired_capacity     = 1
    min_size             = 1
    max_size             = 1
  }

  # Assert IAM profile is set when provided
  assert {
    condition     = aws_launch_template.this.iam_instance_profile[0].name != null
    error_message = "IAM instance profile should be configurable"
  }
}

# ----------------------------------------------------------------
# Multi-subnet deployment
# Expected: ASG spans all provided subnets
# ----------------------------------------------------------------
run "multi_subnet_deployment" {
  command = plan

  variables {
    name               = "test-asg"
    ami_id             = var.test_ami_id
    instance_type      = "t3.micro"
    subnet_ids         = var.subnet_ids
    security_group_ids = var.security_group_ids
    desired_capacity   = 3
    min_size           = 1
    max_size           = 6
  }

  # Assert all subnets are used
  assert {
    condition     = length(aws_autoscaling_group.this.vpc_zone_identifier) == 3
    error_message = "ASG should span all provided subnets for HA"
  }
}
