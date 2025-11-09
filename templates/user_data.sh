#!/bin/bash
# ------------------------------
# EC2 User Data Script
# Installs and starts Nginx web server
# ------------------------------

yum update -y
amazon-linux-extras install nginx1 -y
systemctl start nginx
systemctl enable nginx
echo "<h1>Hi My name is Meraj, Welcome to Intelligent Cloud Cost Optimization System 🚀</h1>" > /usr/share/nginx/html/index.html
