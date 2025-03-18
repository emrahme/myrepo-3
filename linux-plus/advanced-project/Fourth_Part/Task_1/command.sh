IP=$(grep PrivateIpAddress info.json | head -n1 | cut -d'"' -f4) #A delimiter is one or more characters that separate text strings.
sed -i "s/ec2-private_ip/$IP/g" terraform.tf #g G    Copy/append hold space to pattern space.
