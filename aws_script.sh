#!/usr/bin/env bash

# This script targets Amazon Linux.

set -ex

sudo yum -y update
sudo yum -y upgrade

curl https://cache.ruby-lang.org/pub/ruby/2.4/ruby-2.4.4.tar.gz > ruby-2.4.4.tar.gz

# TODO this should error and abort the script if false.
echo The next two lines should match exactly:
sha256sum ruby-2.4.4.tar.gz
echo 254f1c1a79e4cc814d1e7320bc5bdd995dc57e08727d30a767664619a9c8ae5a

# gcc is needed to build ruby.
#
# If zlib-devel is not installed then a zlib file not found error will occur when trying
# to use the ruby after building and installing it.
#
# If openssl-devel is not installed then attempting to install bundler (or any other gem
# I think) will fail with an error about being unable to require openssl.
# readline is needed for the Rails console. I'm not sure if both packages are needed.
sudo yum install -y gcc zlib-devel openssl-devel readline readline-devel

tar xzvf ruby-2.4.4.tar.gz
cd ruby-2.4.4/
sudo mkdir -p /web_socket_tennis_and_dependencies/ruby
./configure --prefix=/web_socket_tennis_and_dependencies/ruby && make && sudo make install
sudo chown -R ec2-user:ec2-user /web_socket_tennis_and_dependencies/

echo 'export PATH=/web_socket_tennis_and_dependencies/ruby/bin:$PATH' >> ~/.bash_profile

PATH=/web_socket_tennis_and_dependencies/ruby/bin:$PATH

gem install bundler

# git is needed to clone the app.
# postgresql-devel is needed to install pg gem.
sudo yum install -y git postgresql-devel

# mini_racer needs g++, and this installs g++.
sudo yum groupinstall -y "Development Tools"

cd /web_socket_tennis_and_dependencies
git clone https://github.com/dcki/web_socket_tennis.git
cd web_socket_tennis
bundle

# TODO nginx, production rails server, elasticache for redis, rds for postgresql.
# TODO Launch all from scratch by aws cli bash script or lambda or an aws deployment
# automation service.
