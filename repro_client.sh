set -e

snapshot_type=$1
kernel_path=$(pwd)"/vmlinux.bin"

curl --unix-socket /tmp/firecracker.socket -i \
  -X PUT 'http://localhost/boot-source'   \
  -H 'Accept: application/json'           \
  -H 'Content-Type: application/json'     \
  -d "{
        \"kernel_image_path\": \"${kernel_path}\",
        \"boot_args\": \"console=ttyS0 reboot=k panic=1 pci=off\"
   }"

rootfs_path=$(pwd)"/bionic.rootfs.ext4"
curl --unix-socket /tmp/firecracker.socket -i \
  -X PUT 'http://localhost/drives/rootfs' \
  -H 'Accept: application/json'           \
  -H 'Content-Type: application/json'     \
  -d "{
        \"drive_id\": \"rootfs\",
        \"path_on_host\": \"${rootfs_path}\",
        \"is_root_device\": true,
        \"is_read_only\": false
   }"

curl --unix-socket /tmp/firecracker.socket -i  \
  -X PUT 'http://localhost/machine-config' \
  -H 'Accept: application/json'            \
  -H 'Content-Type: application/json'      \
  -d '{
      "vcpu_count": 1,
      "mem_size_mib": 5000,
      "ht_enabled": false,
      "track_dirty_pages": true
  }'

curl --unix-socket /tmp/firecracker.socket -i \
  -X PUT 'http://localhost/actions'       \
  -H  'Accept: application/json'          \
  -H  'Content-Type: application/json'    \
  -d '{
      "action_type": "InstanceStart"
   }'

echo "Please start the test program on the VM"

sleep 10

base_snapshot=""
attempt=1

while true
do
  echo "Snapshot attempt #${attempt}"
  ((attempt++))

  echo "Pausing VM"

  curl --unix-socket /tmp/firecracker.socket -i \
    -X PATCH 'http://localhost/vm' \
    -H 'Accept: application/json' \
    -H 'Content-Type: application/json' \
    -d '{
            "state": "Paused"
    }'

  echo "Creating ${snapshot_type} snapshot"

  curl --unix-socket /tmp/firecracker.socket -i \
    -X PUT 'http://localhost/snapshot/create' \
    -H  'Accept: application/json' \
    -H  'Content-Type: application/json' \
    -d "{
            \"snapshot_type\": \"${snapshot_type}\",
            \"snapshot_path\": \"./snapshot_file\",
            \"mem_file_path\": \"./diff_mem_file\"
    }"

  if [ -n "$base_snapshot" ] && [ "$snapshot_type" == "Diff" ]; then
    dd bs=4096 if="diff_mem_file" of="$base_snapshot" conv=sparse,notrunc
  else
    mv diff_mem_file base_mem_file
    base_snapshot="base_mem_file"
  fi

  echo "Shutting down Firecracker"

  # Ugh, is there a better way?
  killall -9 firecracker
  sleep 1

  echo "Loading VM from snapshot '${base_snapshot}'"

  curl --unix-socket /tmp/firecracker.socket -i \
    -X PUT 'http://localhost/snapshot/load' \
    -H  'Accept: application/json' \
    -H  'Content-Type: application/json' \
    -d "{
            \"snapshot_path\": \"./snapshot_file\",
            \"mem_file_path\": \"./${base_snapshot}\",
            \"enable_diff_snapshots\": true,
            \"resume_vm\": true
    }"


  sleep 5
done

