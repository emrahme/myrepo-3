# LAMP Stack and Network ACL Configuration on AWS

This guide outlines the steps to set up a LAMP (Linux, Apache, MySQL, PHP) stack with WordPress on AWS, followed by configuring Network Access Control Lists (NACLs) for enhanced security.

## Part 1: Creating LAMP Stack with WordPress

### 1. Create Security Groups

- **WordPress-BastionHost-SG:**
  - Inbound: SSH (22), HTTP (80) from anywhere (0.0.0.0/0)
- **MariaDB-SG:**
  - Inbound: MySQL (3306), SSH (22) from anywhere (0.0.0.0/0)

### 2. Create EC2 Instance for WordPress App (Public Subnet 1b)

- **VPC:** clarus-vpc-aa
- **Subnet:** clarus-aa-az1b-public-subnet
- **Security Group:** WordPress-BastionHost-SG
- **User Data:**

  ```bash
  #!/bin/bash
  dnf update -y
  dnf install -y httpd wget php-fpm php-mysqli php-json php php-devel
  systemctl start httpd
  systemctl enable httpd
  wget https://wordpress.org/latest.tar.gz
  tar -xzf latest.tar.gz
  cp -r wordpress/* /var/www/html/
  cd /var/www/html/
  cp wp-config-sample.php wp-config.php
  chown -R apache /var/www
  chgrp -R apache /var/www
  chmod 775 /var/www
  find /var/www -type d -exec sudo chmod 2775 {} \;
  find /var/www -type f -exec sudo chmod 0664 {} \;
  systemctl restart httpd
  ```

### 3. Create NAT Gateway & Attach to clarus-private-rt

### 4. Create MariaDB EC2 Instance (Private Subnet 1b)

- **VPC:** clarus-vpc-aa
- **Subnet:** clarus-aa-az1b-private-subnet
- **Security Group:** MariaDB-SG
- **User Data:**

  ```bash
  #!/bin/bash
  dnf update -y
  dnf install mariadb105-server -y
  systemctl start mariadb
  systemctl enable mariadb
  ```

### 5. Secure MariaDB Instance

- Modify MariaDB-SG inbound rules to allow access only from WordPress-BastionHost-SG.
Rule: Mysql 3306, SSH 22  >>>>>> "anywhere (0:/00000)"
							        V
 							        V
 							        V						 
Rule: Mysql 3306, SSH 22  >>>>>> "Wordpress-BastionHost-SG"

### 6. Connect to Private Instance via Bastion Host

- **Start SSH Agent**

```bash
eval "$(ssh-agent)"
```

- **Add Private Key to SSH Agent**

```bash
ssh-add KEY_NAME_HERE.pem
```

- **Connect to WordPress-Bastion Host**

```bash
ssh -A ec2-user@3.88.199.43
```

- **6.4 Connect to Database Instance**

```bash
ssh ec2-user@10.7.2.20
```

### 7. Verify MariaDB Installation

```bash
sudo systemctl status mariadb
```

### 8. Create NAT Gateway (Public Subnet 1a)

- **NAME:** Clarus-NAT
- **VPC:** clarus-vpc-a
- **Subnet:** clarus-az1a-public-subnet

### 9. Configure Private Route Table

- **Destination:** 10.7.0.0/16, **Target:** local
- **Destination:** 0.0.0.0/0, **Target:** NAT Gateway

### 10. Secure MariaDB Installation

```bash
sudo mysql_secure_installation
```

### 11. Connect to MySQL Terminal

```bash
mysql -u root -p
```

- **Show Databases**

```bash
SHOW DATABASES;
```

- **Create Database**

```bash
CREATE DATABASE clarusdb;
```

- **Create User**

```bash
CREATE USER admin IDENTIFIED BY '123456789';
```

- **Grant Permissions**

```bash
GRANT ALL ON clarusdb.* TO admin IDENTIFIED BY '123456789' WITH GRANT OPTION;
```

- **Update Privileges**

```bash
FLUSH PRIVILEGES;
```

- **Select MySQL Database**

```bash
USE mysql;
```

- **List Users**

```bash
SELECT Host, User, Password FROM user;
```

- **Exit MySQL CLI**

```bash
EXIT;
```

### 12. Configure WordPress

-Return back to "Wordpress Instance" to configure Word press database settings.
```bash
cd /var/www/html/
```

- Edit `wp-config.php` to connect to the MariaDB instance.

- Change the config file for database association and restart httpd (You can use your favorite editor).
```bash
sudo vi wp-config.php
```
- Add the below values to `wp-config.php` database settings
```
     define( 'DB_NAME', 'clarusdb' );

     define( 'DB_USER', 'admin' );

     define( 'DB_PASSWORD', '123456789' );

     define( 'DB_HOST', 'PRIVATE_IP_OF_MARIADB' );
```

```bash
Esc :wq ---> Enter
```

- Restart Apache: `sudo systemctl restart httpd`

### 13. Access WordPress

- Open the WordPress instance's public IP in a browser.

## Part 2: Configuring NACLs

### 1. Create Private EC2 Instance (Private Subnet 1a)

- **VPC:** clarus-vpc-aq
- **Subnet:** clarus-qq-az1a-private-subnet
- **Security Group:** Allow SSH and ICMP

### 2. Create NACL

- **Name:** clarus-private1a-nacl
- **VPC:** clarus-vpc-aq

### 3. Configure Inbound Rules

- **Rule 100:** SSH (22) from 0.0.0.0/0 (Allow)
- **Rule 200:** All ICMP IPv4 from 0.0.0.0/0 (Allow)

### 4. Configure Outbound Rules

- **Rule 100:** SSH (22) to 0.0.0.0/0 (Allow)
- **Rule 200:** All ICMP IPv4 to 0.0.0.0/0 (Deny)

### 5. Associate Subnet with NACL

- Associate `clarus-az1a-private-subnet` with `clarus-private1a-nacl`.

### 6. Test Ping from Bastion Host

- Ping the private instance from the Bastion Host.
- It will not work because of the NACLs outbound rule DENY.

### 7. Modify Outbound Rule

- Change NACL Outbound Rule 200 to allow all ICMP IPv4.
```
  Rule        Type              Protocol      Port Range        Destination      Allow/Deny
  100         ssh(22)           TCP(6)        22                0.0.0.0/0         Allow
  200         All ICMP - IPv4   ICMP(1)       ALL               0.0.0.0/0         Deny
  |                                           |                                   |
  |                                           |                                   |
  V                                           V                                   V
  100         ssh(22)           TCP(6)        22                0.0.0.0/0         Allow
  200         All ICMP - IPv4   ICMP(1)       ALL               0.0.0.0/0         Allow
```

### 8. Verify Ping

- Ping the private instance again.

### 9. Test SSH

- SSH to the private instance (will fail due to ephemeral ports).
- It will not work because of the ephemeral ports. Explain ephemeral ports(1024-65535).

### 10. Add Ephemeral Ports

- Add a rule to allow ephemeral ports (1024-65535) in the outbound rules.
```
  Rule        Type              Protocol      Port Range        Destination      Allow/Deny
  100         ssh(22)           TCP(6)        22                0.0.0.0/0         Allow
  200         All ICMP - IPv4   ICMP(1)       ALL               0.0.0.0/0         Allow
  |                                           |                                   |
  |                                           |                                   |
  V                                           V                                   V
  100         Custom TCP Rule   TCP(6)        32768 - 65535     0.0.0.0/0         Allow
  200         All ICMP - IPv4   ICMP(1)       ALL               0.0.0.0/0         Allow
```

### 11. Verify SSH

- SSH to the private instance again.

### 12. Terminate Resources

- Terminate all created resources.

**Note:** Replace IP addresses and key names with your actual values.

**Warning:** Do not forget to terminate/delete the resources you have created!
