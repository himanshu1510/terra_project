provider "aws" {
  region = "ap-south-1"
  profile = "himanshu"
}

#create security group

resource "aws_security_group" "allow_tls" {
  name        = "launch-wizard-6"
  description = "Allow http and ssh"
  ingress {
    description = "SSH Port"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "HTTPD port"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "local host"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "Custom tcp"
    from_port   = 81
    to_port     = 81
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "allow_tls"
  }
}

# launch ec2 instance

resource "aws_instance" "web" {
  ami           = "ami-0447a12f28fddb066"
  instance_type = "t2.micro"
  key_name =  "mykey111"
  security_groups =  [ "launch-wizard-5" ]
  
connection {
    type     = "ssh"
    user     = "ec2-user"
    private_key = file("C:/Users/hp19tu/Downloads/mykey111.pem")
    host     = aws_instance.web.public_ip
  }
  
  provisioner "remote-exec" {
    inline = [
      "sudo yum install httpd php git -y",
      "sudo systemctl restart httpd",
      "sudo systemctl enable httpd"
      ]
  }

  tags = {
    Name = "linuxOS"
  }

}

#create ebs volume

resource "aws_ebs_volume" "ebs_volume1" {
  availability_zone = aws_instance.web.availability_zone
  size              = 1

  tags = {
    Name = "linux_volume_1"
  }
}

# attach ebs volume

resource "aws_volume_attachment" "ebs_att" {
  device_name = "/dev/sdh"
  volume_id   = aws_ebs_volume.ebs_volume1.id
  instance_id = aws_instance.web.id
  force_detach = true
}

resource "null_resource" "harddisk1" {
   depends_on = [
    aws_cloudfront_distribution.s3_distribution,
  ]
/* provisioner "local-exec" {
 command = " terraform state mv  C:/Users/hp19tu/Desktop/terraform/s3/terra_photo.txt   C:/Users/hp19tu/Desktop/website/ "

 }*/
provisioner "file" {
    source      = "C:/Users/hp19tu/Desktop/terraform/s3/terra_photo.txt"   
    destination = "C:/Users/hp19tu/Desktop/website" 
  }
}

resource "null_resource" "harddisk2" {
   depends_on = [
    null_resource.harddisk1,
  ]

 provisioner "local-exec" {
        working_dir = "C:/Users/hp19tu/Desktop/website"
	command = "git add ."
        
}
}
resource "null_resource" "harddisk3" {
   depends_on = [
     null_resource.harddisk2,
  ]

 provisioner "local-exec" {
        working_dir = "C:/Users/hp19tu/Desktop/website"
	command = "git commit ."
        }
}
resource "null_resource" "harddisk4" {
   depends_on = [
     null_resource.harddisk3,
  ]

 provisioner "local-exec" {
        working_dir = "C:/Users/hp19tu/Desktop/website"
	command = "git push"
        }
}
# mount harddisk 

resource "null_resource" "harddisk" {
 depends_on = [
    null_resource.harddisk2,
  ]

provisioner "local-exec" {
	    command = "echo  ${aws_cloudfront_distribution.s3_distribution.domain_name} > terra_photo.txt"
              	}
 	


   connection {
    type     = "ssh"
    user     = "ec2-user"
    private_key = file("C:/Users/hp19tu/Downloads/mykey111.pem")
    host     = aws_instance.web.public_ip
  }
  
  provisioner "remote-exec" {
    inline = [
      "sudo mkfs.ext4 /dev/xvdh",
      "sudo mount /dev/xvdh  /var/www/html",
      "sudo rm -rf  /var/www/html/*",
      "sudo git clone https://github.com/himanshu1510/terra_photos.git  /var/www/html/",
      "chmod +x t1.html"
    ]
  }

}

#create a s3 bucket
resource "aws_s3_bucket" "bucket" {
  depends_on = [
    aws_volume_attachment.ebs_att,
  ]

  bucket = "my-tf-test-bucket-myweb"
  acl    = "private"
    tags = {
    Name        = "web_bucket"
  }
  force_destroy = true

  
  provisioner "local-exec" {

        command = "aws s3 sync C:/Users/hp19tu/Desktop/terra_photo s3://my-tf-test-bucket-myweb --acl public-read --profile himanshu "
  
}

}


#creating CloudFront

locals {
  s3_origin_id = "myS3Origin"
}

resource "aws_cloudfront_distribution" "s3_distribution" {
   depends_on = [
    aws_volume_attachment.ebs_att,
  ]

  origin {
    domain_name = aws_s3_bucket.bucket.bucket_regional_domain_name
    origin_id   = local.s3_origin_id
  }

  enabled             = true
  is_ipv6_enabled     = true
  comment             = "Some comment"
  default_root_object = "index.html"

  default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = local.s3_origin_id

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "allow-all"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }

  # Cache behavior with precedence 0
  ordered_cache_behavior {
    path_pattern     = "/content/immutable/*"
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD", "OPTIONS"]
  target_origin_id = local.s3_origin_id

    forwarded_values {
      query_string = false
      headers      = ["Origin"]

      cookies {
        forward = "none"
      }
    }

    min_ttl                = 0
    default_ttl            = 86400
    max_ttl                = 31536000
    compress               = true
    viewer_protocol_policy = "redirect-to-https"
  }

  # Cache behavior with precedence 1
  ordered_cache_behavior {
    path_pattern     = "/content/*"
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = local.s3_origin_id

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
    compress               = true
    viewer_protocol_policy = "redirect-to-https"
  }

  price_class = "PriceClass_200"

  restrictions {
    geo_restriction {
      restriction_type = "whitelist"
      locations        = ["IN", "CA", "GB", "DE"]
    }
  }

  tags = {
    Environment = "production"
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
}

# give the ip of your os

output "myos_ip" {
  value = aws_instance.web.public_ip
}

#save the public ip in a file publicip.txt

resource "null_resource" "nulllocal2"  {
	provisioner "local-exec" {
	    command = "echo  ${aws_instance.web.public_ip} > publicip.txt"
              	}
}

