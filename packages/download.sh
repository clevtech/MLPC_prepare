#!/bin/bash

rm Packages.gz

sudo apt-get update
sudo apt-get install -y ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

# Add the repository to Apt sources:
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update

curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg \
  && curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
    sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
    sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list

sudo apt-get update

sudo apt install -y apt-rdepends



# Path to the requirements file
REQUIREMENTS_FILE="requirements.txt"

# Directory to store downloaded .deb files
DOWNLOAD_DIR="./"

# Check if requirements file exists
if [ ! -f "$REQUIREMENTS_FILE" ]; then
  echo "Error: requirements.txt file not found!"
  exit 1
fi

# Create a directory for downloads if it doesn't exist
mkdir -p "$DOWNLOAD_DIR"

# Read each package from requirements.txt and download with dependencies
while IFS= read -r package; do
  if [ -n "$package" ]; then
    echo "Processing package: $package"
    apt-rdepends "$package" 2>/dev/null | grep -E '^\w' | xargs -n 1 apt-get download -o=dir::cache="$DOWNLOAD_DIR" || {
      echo "Error downloading $package"
      continue
    }
    echo "Downloaded $package successfully."
  fi
done < "$REQUIREMENTS_FILE"

dpkg-scanpackages . /dev/null | gzip -9c > Packages.gz


echo "All downloads completed. Files are stored in $DOWNLOAD_DIR."

