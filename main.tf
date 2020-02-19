provider "aws" {
  profile = "default"
  region = "us-east-2"
}
/*resource "aws_vpc" "heeled_vpc" {
  cidr_block = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support = true
}

resource "aws_subnet" "heeled_subnet" {
  vpc_id     = "${aws_vpc.heeled_vpc.id}"
  cidr_block = "10.0.1.0/24"
  depends_on = ["aws_internet_gateway.internet_gateway"]

}

resource "aws_security_group" "allow_tcp" {
  name        = "allow_tcp"
  description = "Allow TCP inbound traffic"
  vpc_id      = "${aws_vpc.heeled_vpc.id}"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
  }
}
resource "aws_instance" "heeled_instance" {
  ami = "${var.ami_id}"
  instance_type = "t2.micro"
  key_name      = "${aws_key_pair.ssh-user.key_name}"
  security_groups = ["${aws_security_group.allow_tcp.id}"]
  subnet_id = "${aws_subnet.heeled_subnet.id}"



}
resource "aws_eip" "lb" {
  instance = "${aws_instance.heeled_instance.id}"
  vpc      = true
}
resource "aws_key_pair" "ssh-user" {
  key_name   = "deployer-key"
  public_key = "${file("./keys/id_rsa.pub")}"
}

resource "aws_internet_gateway" "internet_gateway" {
  vpc_id = "${aws_vpc.heeled_vpc.id}"
}

resource "aws_route_table" "route_table" {
  vpc_id = "${aws_vpc.heeled_vpc.id}"
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.internet_gateway.id}"
  }
}

resource "aws_route_table_association" "route_table_assoc" {
  subnet_id      = aws_subnet.heeled_subnet.id
  route_table_id = aws_route_table.route_table.id
}*/

resource "aws_s3_bucket" "heeled_bucket" {
  bucket = "heeled-sqs-bucket"
}

resource "aws_s3_bucket_notification" "bucket_notification" {
  bucket = "${aws_s3_bucket.heeled_bucket.id}"

  queue {
    queue_arn = "${aws_sqs_queue.heeled_bucket_queue.arn}"
    events = [
      "s3:ObjectCreated:*"]
    filter_suffix = ".log"
  }
}
resource "aws_sqs_queue" "heeled_bucket_queue" {
  name = "s3-event-notification-queue"


}

resource "aws_sqs_queue_policy" "sqs_queue_policy" {
  queue_url = "${aws_sqs_queue.heeled_bucket_queue.id}"

  policy = <<POLICY
{
  "Version": "2012-10-17",
  "Id": "sqspolicy",
  "Statement": [
    {
      "Sid": "First",
      "Effect": "Allow",
      "Principal": "*",
      "Action": "sqs:SendMessage",
      "Resource": "${aws_sqs_queue.heeled_bucket_queue.arn}",
      "Condition": {
        "ArnEquals": {
          "aws:SourceArn": "${aws_s3_bucket.heeled_bucket.arn}"
        }
      }
    }
  ]
}
POLICY
}

resource "aws_sns_topic" "sns_lambda_topic" {
  name = "sqs-updates-topic"
}

resource "aws_iam_role" "iam_lambda_role" {
  name = "test_role_lambda"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_policy" "lambda_policy" {
  name = "test-policy"
  description = "A test policy"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
                "logs:CreateLogGroup",
                "logs:CreateLogStream",
                "logs:PutLogEvents",
                "sqs:SendMessage",
                  "sns:SendMessage",
                "sqs:ReceiveMessage",
              "sqs:DeleteMessage",
              "sqs:GetQueueAttributes",
"sns:Publish"
            ],
      "Effect": "Allow",
      "Resource": "*"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "test-attach" {
  role = "${aws_iam_role.iam_lambda_role.name}"
  policy_arn = "${aws_iam_policy.lambda_policy.arn}"
}

resource "aws_lambda_function" "lambda_sqs_function" {
  function_name = "test_lambda"
  handler = "lambda_function.lambda_handler"
  role = "${aws_iam_role.iam_lambda_role.arn}"
  runtime = "python3.7"
  filename = "lambda_function.py.zip"
}

resource "aws_lambda_event_source_mapping" "example" {
  event_source_arn = "${aws_sqs_queue.heeled_bucket_queue.arn}"
  function_name = "${aws_lambda_function.lambda_sqs_function.arn}"
}

resource "aws_lambda_function_event_invoke_config" "example" {
  function_name = "${aws_lambda_function.lambda_sqs_function.function_name}"

  destination_config {
    on_failure {
      destination = "${aws_sqs_queue.heeled_bucket_queue.arn}"
    }

    on_success {
      destination = "${aws_sns_topic.sns_lambda_topic.arn}"
    }
  }
}

resource "aws_lambda_permission" "with_sqs" {
  statement_id = "AllowExecutionFromSQS"
  action = "lambda:InvokeFunction"
  function_name = "${aws_lambda_function.lambda_sqs_function.function_name}"
  principal = "sns.amazonaws.com"
  source_arn = "${aws_sqs_queue.heeled_bucket_queue.arn}"
}





