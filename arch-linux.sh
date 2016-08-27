#!/bin/sh

# http://kvz.io/blog/2013/11/21/bash-best-practices/

# make your script exit when a command fails 
set -o errexit

# to catch pipe fails eg. mysqldump |gzip
set -o pipefail 

# exit when your script tries to use undeclared variables 
set -o nounset

# trace what gets executed, usefull when debugging
# set -o xtrace 

timedatectl set-ntp true

gdisk /dev/sda
