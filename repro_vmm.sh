set -

while true
do
  rm -f /tmp/firecracker.socket
  firecracker --api-sock /tmp/firecracker.socket
done
