#!/bin/bash
set -eou pipefail
# Download the repository as a ZIP file
curl -L -o bashlog.zip https://github.com/Zordrak/bashlog/archive/refs/heads/master.zip

# Unzip the file to the desired directory
unzip bashlog.zip -d ./dependencies/

# Move the files to the desired location
mv ./dependencies/bashlog-master ./dependencies/bashlog

# Clean up the downloaded ZIP file
rm bashlog.zip
