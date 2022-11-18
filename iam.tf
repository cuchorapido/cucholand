// IAM role for S3 access
resource "aws_iam_role" "allow_s3_route53" {
  name   = "${module.label.id}-allow-ec2-s3-route53"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_instance_profile" "mc" {
  name = "${module.label.id}-instance-profile"
  role = aws_iam_role.allow_s3_route53.name
}

resource "aws_iam_role_policy" "mc_allow_ec2_to_s3" {
  name   = "${module.label.id}-allow-ec2-to-s3"
  role   = aws_iam_role.allow_s3_route53.id
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": ["s3:ListBucket"],
      "Resource": ["arn:aws:s3:::${local.bucket}"]
    },
    {
      "Effect": "Allow",
      "Action": [
        "s3:PutObject",
        "s3:GetObject",
        "s3:DeleteObject"
      ],
      "Resource": ["arn:aws:s3:::${local.bucket}/*"]
    }
  ]
}
EOF
}

#TODO: make hosted zone id a variable

resource "aws_iam_role_policy" "mc_allow_ec2_set_route53" {
  name   = "${module.label.id}-allow-ec2-to-route53"
  role   = aws_iam_role.allow_s3_route53.id
  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "route53:ChangeResourceRecordSets"
            ],
            "Resource": [
                "arn:aws:route53:::hostedzone/ZFMV5BE45DZ2G"
            ]
        },
        {
            "Effect": "Allow",
            "Action": [
                "route53:ListHostedZonesByName"
            ],
            "Resource": [
                "*"
            ]
        }
    ]
}
EOF
}

# resource "aws_route53_record" "dev-ns" {
#   zone_id = aws_route53_zone.main.zone_id
#   name    = "dev.example.com"
#   type    = "NS"
#   ttl     = "30"
#   records = aws_route53_zone.dev.name_servers
# }