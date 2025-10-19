# IAM Role
resource "aws_iam_role" "this" {
  name               = var.name
  assume_role_policy = var.assume_role_policy

  tags = merge(
    var.tags,
    {
      Name = var.name
    }
  )
}

# Attach policies to role
resource "aws_iam_role_policy_attachment" "this" {
  count = length(var.policy_arns)

  role       = aws_iam_role.this.name
  policy_arn = var.policy_arns[count.index]
}

# Instance Profile (for EC2)
resource "aws_iam_instance_profile" "this" {
  count = var.create_instance_profile ? 1 : 0

  name = var.name
  role = aws_iam_role.this.name

  tags = merge(
    var.tags,
    {
      Name = var.name
    }
  )
}
