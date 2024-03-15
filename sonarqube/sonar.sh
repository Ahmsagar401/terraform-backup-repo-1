provider "aws" {
    region = "us-east-1"

}

resource "aws_s3_bucket" "my_bucket" {
    count = length(var.buckets)
    bucket = var.buckets[count.index]
}

output "aws_s3_bucket" {
    value = aws_s3_bucket.my_bucket.*.bucket
    description = "The buckets are"
}
ubuntu@ip-172-31-13-73:~/terraform_inst/sam$ ls
main.tf  terraform.tfstate  terraform.tfstate.backup  variable.tf
ubuntu@ip-172-31-13-73:~/terraform_inst/sam$ cat variable.tf 
variable "buckets" {
   type = list
   default = ["sudham-bucket1","sudham-bucket2","sudham-bucket3"]
}
ubuntu@ip-172-31-13-73:~/terraform_inst/sam$ cd ..
ubuntu@ip-172-31-13-73:~/terraform_inst$ ls
README.md  ami  count  data_block  inst_multi_region  main.tf  multi_buckets  new_security_group  newinst  newvpc  pract  sam  sonarqube  static_website  workspace
ubuntu@ip-172-31-13-73:~/terraform_inst$ cd sonarqube/
ubuntu@ip-172-31-13-73:~/terraform_inst/sonarqube$ ls
main.tf  sonar.sh  terraform.tfstate  terraform.tfstate.backup
ubuntu@ip-172-31-13-73:~/terraform_inst/sonarqube$ cat main.tf 
provider "aws" {
  region = "ap-south-1"
}

resource "aws_instance" "sonarqube_server" {
    ami = "ami-03f4878755434977f"
    instance_type = "t2.medium"
    vpc_security_group_ids = [aws_security_group.my_security_group.id]
    user_data = file("sonar.sh")

    tags = {
        "Name" = "sonarqube"
    }
}

resource "aws_security_group" "my_security_group" {
    name = "security"
    description = " allow ssh and http port"

    ingress {
        from_port = 80
        to_port = 80
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    ingress {
        from_port = 22
        to_port = 22
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    ingress {
        from_port = 8080
        to_port = 8080
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    ingress {
        from_port = 9000
        to_port = 9000
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
    
    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }

}
ubuntu@ip-172-31-13-73:~/terraform_inst/sonarqube$ ls
main.tf  sonar.sh  terraform.tfstate  terraform.tfstate.backup
ubuntu@ip-172-31-13-73:~/terraform_inst/sonarqube$ cat sonar.sh 
#!/bin/bash
cp /etc/sysctl.conf /root/sysctl.conf_backup
cat <<EOT> /etc/sysctl.conf
vm.max_map_count=262144
fs.file-max=65536
ulimit -n 65536
ulimit -u 4096
EOT
cp /etc/security/limits.conf /root/sec_limit.conf_backup
cat <<EOT> /etc/security/limits.conf
sonarqube - nofile 65536
sonarqube - nproc 409
EOT
sudo apt-get update -y
sudo apt-get install openjdk-11-jdk -y
sudo update-alternatives --config java
java -version
sudo apt update
wget -q https://www.postgresql.org/media/keys/ACCC4CF8.asc -O - | sudo apt-key add -
sudo sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt/ `lsb_release -cs`-pgdg main" >> 
/etc/apt/sources.list.d/pgdg.list'
sudo apt install postgresql postgresql-contrib -y
#sudo -u postgres psql -c "SELECT version();"
sudo systemctl enable postgresql.service
sudo systemctl start postgresql.service
sudo echo "postgres:admin123" | chpasswd
runuser -l postgres -c "createuser sonar"
sudo -i -u postgres psql -c "ALTER USER sonar WITH ENCRYPTED PASSWORD 'admin123';"
sudo -i -u postgres psql -c "CREATE DATABASE sonarqube OWNER sonar;"
sudo -i -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE sonarqube to sonar;"
systemctl restart postgresql
#systemctl status -l postgresql
netstat -tulpena | grep postgres
sudo mkdir -p /sonarqube/
cd /sonarqube/
sudo curl -O https://binaries.sonarsource.com/Distribution/sonarqube/sonarqube-8.3.0.34182.zip
sudo apt-get install zip -y
sudo unzip -o sonarqube-8.3.0.34182.zip -d /opt/
sudo mv /opt/sonarqube-8.3.0.34182/ /opt/sonarqube
sudo groupadd sonar
sudo useradd -c "SonarQube - User" -d /opt/sonarqube/ -g sonar sonar
sudo chown sonar:sonar /opt/sonarqube/ -R
cp /opt/sonarqube/conf/sonar.properties /root/sonar.properties_backup
cat <<EOT> /opt/sonarqube/conf/sonar.properties
sonar.jdbc.username=sonar
sonar.jdbc.password=admin123
sonar.jdbc.url=jdbc:postgresql://localhost/sonarqube
sonar.web.host=0.0.0.0
sonar.web.port=9000
sonar.web.javaAdditionalOpts=-server
sonar.search.javaOpts=-Xmx512m -Xms512m -XX:+HeapDumpOnOutOfMemoryError
sonar.log.level=INFO
sonar.path.logs=logs
EOT
cat <<EOT> /etc/systemd/system/sonarqube.service
[Unit]
Description=SonarQube service
After=syslog.target network.target
[Service]
Type=forking
ExecStart=/opt/sonarqube/bin/linux-x86-64/sonar.sh start
ExecStop=/opt/sonarqube/bin/linux-x86-64/sonar.sh stop
User=sonar
Group=sonar
Restart=always
LimitNOFILE=65536
LimitNPROC=4096
[Install]
WantedBy=multi-user.target
EOT
systemctl daemon-reload
systemctl enable sonarqube.service
#systemctl start sonarqube.service
#systemctl status -l sonarqube.service
apt-get install nginx -y
rm -rf /etc/nginx/sites-enabled/default
rm -rf /etc/nginx/sites-available/default
cat <<EOT> /etc/nginx/sites-available/sonarqube
server{
 listen 80;
 server_name sonarqube.groophy.in;
 access_log /var/log/nginx/sonar.access.log;
 error_log /var/log/nginx/sonar.error.log;
 proxy_buffers 16 64k;
 proxy_buffer_size 128k;
 location / {
 proxy_pass http://127.0.0.1:9000;
 proxy_next_upstream error timeout invalid_header http_500 http_502 http_503 http_504;
 proxy_redirect off;
 proxy_set_header Host \$host;
 proxy_set_header X-Real-IP \$remote_addr;
 proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
 proxy_set_header X-Forwarded-Proto http;
 }
}
EOT
ln -s /etc/nginx/sites-available/sonarqube /etc/nginx/sites-enabled/sonarqube
systemctl enable nginx.service
#systemctl restart nginx.service
sudo ufw allow 80,9000,9001/tcp
echo "System reboot in 30 sec"
sleep 30
reboot
