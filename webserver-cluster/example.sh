#!/bin/bash
apt install apache2 -y
systemctl start apache2
systemctl enable apache2
apt-get install busybox -y
cat > index.html
<<EOF
<h1>Hello, World</h1>
<p>DB address: ${db_address}</p>
<p>DB port: ${db_port}</p>
EOF busybox apache2 -f -p ${var.server_port} &