#!/bin/bash

sudo ./hdd.sh

# Directory containing the .deb files
DEB_DIR="./packages"

echo "Installing drivers"
sudo dpkg -i  ./drivers/nvidia-driver-local-repo-ubuntu2204-560.35.03_1.0-1_amd64.deb &>/dev/null
sudo cp /var/nvidia-driver-local-repo-ubuntu2204-560.35.03/nvidia-driver-local-73056A76-keyring.gpg /usr/share/keyrings/
echo "NVIDIA driver is installed"
echo ""
echo "Trying smi"
nvidia-smi
echo ""
echo "Done installing NVIDIA driver"
echo ""
echo "Trying installing CUDA..."
sudo cp ./drivers/cuda-ubuntu2204.pin /etc/apt/preferences.d/cuda-repository-pin-600 &>/dev/null
sudo dpkg -i  ./drivers/cuda-repo-ubuntu2204* &>/dev/null
sudo cp /var/cuda-repo-ubuntu2204-12-6-local/cuda-*-keyring.gpg /usr/share/keyrings/ &>/dev/null
sudo apt update &>/dev/null
echo "Done installing CUDA"

# Get the directory of the script and append 'packages'
SCRIPT_DIR=$(dirname "$(realpath "$0")")
echo SCRIPT_DIR
REPO_PATH_IN="$SCRIPT_DIR/packages"
sudo rm -rf /var/packages
sudo mkdir /var/packages
REPO_PATH="/var/packages"

sudo cp -R "$REPO_PATH_IN" /var

# Ensure the 'packages' directory exists and is not empty
if [ ! -d "$REPO_PATH" ] || [ -z "$(ls -A "$REPO_PATH")" ]; then
    echo "Error: Repository path $REPO_PATH does not exist or is empty."
    exit 1
fi

# Construct the repository line
REPO_LINE="deb [trusted=yes] file:$REPO_PATH ./"

# Check and add the repository to sources.list if not already present
if grep -Fxq "$REPO_LINE" /etc/apt/sources.list; then
    echo "The repository is already added to /etc/apt/sources.list."
else
    echo "$REPO_LINE" | sudo tee -a /etc/apt/sources.list
    echo "Repository added successfully."
fi

# Update APT
echo "Updating APT cache..."
sudo apt update &>/dev/null
echo "APT cache updated."


# Set a high priority for the local repository
PRIORITY_FILE="/etc/apt/preferences.d/local-repo"
echo "Setting high priority for the local repository."

sudo tee "$PRIORITY_FILE" > /dev/null <<EOL
Package: *
Pin: origin ""
Pin-Priority: 1001
EOL

echo "Local repository prioritized successfully."

echo "Starting installation of local debs"
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin openssh-server nmap net-tools curl vlc cuda-toolkit-12-6 nvidia-container-toolkit 

echo "Testing Docker:"
sudo ./load.sh
sudo docker ps
echo "Done"

echo "Trying CUDA on docker"
sudo mkdir -p /etc/systemd/system/docker.service.d
sudo tee /etc/systemd/system/docker.service.d/override.conf <<EOF
[Service]
ExecStart=
ExecStart=/usr/bin/dockerd --host=fd:// --add-runtime=nvidia=/usr/bin/nvidia-container-runtime
EOF

sudo systemctl daemon-reload &>/dev/null

sudo systemctl restart docker &>/dev/null

sudo docker run --rm --runtime=nvidia --gpus all ubuntu nvidia-smi

echo "Done Docker NVIDIA"
