#!/bin/bash

# Minimum size in bytes (1.5 TB = 1.5 * 1024^4)
MIN_SIZE=$((1500 * 1024 * 1024 * 1024))

# Directory for the mount point
MOUNT_POINT="/cold"

# Detect disks with capacity greater than 1.5 TB
DISK=$(lsblk -b -d -o NAME,SIZE | awk -v min_size="$MIN_SIZE" 'NR>1 && $2 > min_size {print $1}' | head -n 1)

if [ -z "$DISK" ]; then
  echo "No disk found with more than 1.5 TB of capacity."
  exit 1
fi

echo "Found disk: /dev/$DISK"

# Create the mount point if it doesn't exist
if [ ! -d "$MOUNT_POINT" ]; then
  echo "Creating mount point at $MOUNT_POINT"
  sudo mkdir -p "$MOUNT_POINT"
fi

# Check if the disk is already partitioned and formatted
PARTITION="/dev/${DISK}1"
if ! lsblk -o NAME | grep -q "${DISK}1"; then
  echo "Partitioning disk /dev/$DISK"
  echo -e "o\nn\np\n1\n\n\nw" | sudo fdisk "/dev/$DISK"

  echo "Formatting partition $PARTITION as ext4"
  sudo mkfs.ext4 "$PARTITION"
fi

# Mount the disk
echo "Mounting $PARTITION to $MOUNT_POINT"
sudo mount "$PARTITION" "$MOUNT_POINT"

# Ensure the disk is mounted at startup
FSTAB_ENTRY="$PARTITION $MOUNT_POINT ext4 defaults 0 0"
if ! grep -q "$PARTITION" /etc/fstab; then
  echo "Adding $PARTITION to /etc/fstab"
  echo "$FSTAB_ENTRY" | sudo tee -a /etc/fstab
fi

echo "Disk /dev/$DISK successfully mounted to $MOUNT_POINT and configured to auto-mount at startup."

