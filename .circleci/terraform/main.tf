# whoami
data "external" "username" {
  program = "whoami"
}

# aws_vpc.devsecops-vpc:
resource "aws_vpc" "devsecops-vpc" {
    assign_generated_ipv6_cidr_block = false
    cidr_block                       = "172.31.0.0/16"
    enable_classiclink               = false
    enable_classiclink_dns_support   = false
    enable_dns_hostnames             = true
    enable_dns_support               = true
    instance_tenancy                 = "default"
    tags                             = {}
    tags_all                         = {}
}

# aws_security_group.rds-sec:
resource "aws_security_group" "rds-sec" {
    description = "invoicer db security group"
    egress      = [
        {
            cidr_blocks      = [
                "0.0.0.0/0",
            ]
            description      = ""
            from_port        = 0
            ipv6_cidr_blocks = []
            prefix_list_ids  = []
            protocol         = "-1"
            security_groups  = []
            self             = false
            to_port          = 0
        },
    ]
    ingress     = [
        {
            cidr_blocks      = [
                "0.0.0.0/0",
            ]
            description      = ""
            from_port        = 5432
            ipv6_cidr_blocks = []
            prefix_list_ids  = []
            protocol         = "tcp"
            security_groups  = []
            self             = false
            to_port          = 5432
        },
    ]
    name        = "invoicer_db"
    tags        = {}
    tags_all    = {}
    timeouts {}
}

resource "random_password" "dbpass" {
  length = 16
  special = true
}

# aws_db_instance.invoicer-db:
resource "aws_db_instance" "invoicer-db" {
    allocated_storage                     = 5
    auto_minor_version_upgrade            = true
    availability_zone                     = "us-east-1f"
    backup_retention_period               = 1
    backup_window                         = "05:10-05:40"
    ca_cert_identifier                    = "rds-ca-2019"
    copy_tags_to_snapshot                 = false
    customer_owned_ip_enabled             = false
    db_name                               = "invoicer"
    db_subnet_group_name                  = "default"
    delete_automated_backups              = true
    deletion_protection                   = false
    enabled_cloudwatch_logs_exports       = []
    engine                                = "postgres"
    engine_version                        = "13.7"
    iam_database_authentication_enabled   = false
    identifier                            = "invoicer-db"
    instance_class                        = "db.t4g.micro"
    iops                                  = 0
    license_model                         = "postgresql-license"
    maintenance_window                    = "wed:03:02-wed:03:32"
    max_allocated_storage                 = 0
    monitoring_interval                   = 0
    multi_az                              = false
    option_group_name                     = "default:postgres-13"
    parameter_group_name                  = "default.postgres13"
    password                              = random_password.dbpass.result
    performance_insights_enabled          = false
    performance_insights_retention_period = 0
    port                                  = 5432
    publicly_accessible                   = true
    security_group_names                  = []
    skip_final_snapshot                   = true
    storage_encrypted                     = false
    storage_type                          = "gp2"
    tags                                  = {
      environment-name = aws_elastic_beanstalk_environment.invoicer-env
      Owner = data.username.result
    }
    tags_all                              = {}
    username                              = "invoicer"
    vpc_security_group_ids                = [
        aws_security_group.rds-sec.id
    ]

    timeouts {}
}

# app version bucket
resource "aws_s3_bucket" "d-s-r-invoicer-eb" {
    arn                         = "arn:aws:s3:::d-s-r-invoicer-eb"
    bucket                      = "d-s-r-invoicer-eb"
    hosted_zone_id              = "Z3AQBSTGFYJSTF"
    object_lock_enabled         = false
    request_payer               = "BucketOwner"
    tags                        = {}
    tags_all                    = {}

    grant {
        id          = "6ca278e8b13e143c2ae1a301bb02ad1b86b3f77a6eca46d0917e67086a89a8a6"
        permissions = [
            "FULL_CONTROL",
          ]
        type        = "CanonicalUser"
      }

    timeouts {}

    versioning {
        enabled    = false
        mfa_delete = false
      }
  }

# app-version.json file
resource "aws_s3_bucket_object" "app-version-file" {
  bucket = aws_s3_bucket.d-s-r-invoicer-eb.id
  key = "app-version.json"
  source = "${path.module}/app-version.json"
  etag = filemd5("${path.module}/app-version.json")
}

# aws_elastic_beanstalk_application.invoicer:
resource "aws_elastic_beanstalk_application" "invoicer" {
    description = "Securing DevOps Invoicer application"
    name        = "invoicer"
    tags        = {}
    tags_all    = {}
}

# aws elasticbeanstalk app version
resource "aws_elastic_beanstalk_application_version" "invoicer-ver" {
  name = "invoicer-eb-app-version"
  application = "invoicer"
  bucket = aws_s3_bucket.d-s-r-invoicer-eb.id
  key = "app-version.json"
}

# aws elasticbeanstalk app environment
resource "aws_elastic_beanstalk_environment" "invoicer-env" {
    application          = aws_elastic_beanstalk_application.invoicer.name
    name                 = "invoicer-env"
    solution_stack_name  = "64bit Amazon Linux 2 v3.4.19 running Docker"
    description            = "Invoicer APP"

    setting {
                name="INVOICER_POSTGRES_DB"
                namespace= "aws:elasticbeanstalk:application:environment"
                resource= ""
                value= "invoicer"
              }
    setting {
                name= "INVOICER_POSTGRES_HOST"
                namespace= "aws:elasticbeanstalk:application:environment"
                resource= ""
                value= "invoicer-db.cyauywvpcwjw.us-east-1.rds.amazonaws.com"
              }
    setting {
                name= "INVOICER_POSTGRES_PASSWORD"
                namespace= "aws:elasticbeanstalk:application:environment"
                resource= ""
                value= random_password.dbpass.result
              }
    setting {
                name= "INVOICER_POSTGRES_USER"
                namespace= "aws:elasticbeanstalk:application:environment"
                resource= ""
                value= "invoicer"
              }
    user_data = templatefile("update-elasticbeanstalk-environment.sh.tpl", {
      appname = "${aws_elastic_beanstalk_application.invoicer.name}"
      envid = "${aws_elastic_beanstalk_environment.invoicer-env}"
      verlabel = "${aws_elastic_beanstalk_application_version.invoicer-ver.name}"
    })
}


