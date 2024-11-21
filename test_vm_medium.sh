# This Bash script sets up a Vagrant environment with multiple virtual machines (VMs) using the Ubuntu 18.04 (Bionic) base box. It performs the following tasks:

# 1. Checks if an SSH key for the VMs already exists, and generates a new one if it doesn't.
# 2. Creates a directory for the Vagrant machines and generates a Vagrantfile that configures the VMs.
# 3. Provisions the VMs with the generated SSH public key and creates a user account for each VM with the username "test{i}", where {i} is the machine number.
# 4. Starts the VMs in parallel and checks their status.
# @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@


#!/bin/bash

# Initial configurations
SSH_KEY_DIR="/home/pryor/.ssh"
SSH_KEY_NAME="test_machinekey"
VM_COUNT=5
VAGRANT_DIR="vagrant_machines"
VM_BOX="ubuntu/bionic64"

# Create the SSH key if it doesn't exist
if [[ ! -f "$SSH_KEY_DIR/$SSH_KEY_NAME" ]]; then
  echo "Generating SSH key..."
  ssh-keygen -t rsa -b 2048 -f "$SSH_KEY_DIR/$SSH_KEY_NAME" -q -N ""
else
  echo "SSH key already exists."
fi

# Set up the directory for Vagrant
mkdir -p "$VAGRANT_DIR"
cd "$VAGRANT_DIR" || exit

# Create the Vagrantfile
cat <<'EOF' > Vagrantfile
Vagrant.configure("2") do |config|
  # Configurable variables
  ssh_key_dir = ENV['SSH_KEY_DIR']
  ssh_key_name = ENV['SSH_KEY_NAME']
  vm_count = ENV['VM_COUNT'].to_i
  vm_box = ENV['VM_BOX']

  # SSH settings
  config.ssh.insert_key = false
  config.ssh.verify_host_key = false

  # Provisioning machines
  config.vm.provision "shell" do |s|
    ssh_pub_key = File.read("#{ssh_key_dir}/#{ssh_key_name}.pub").strip
    s.inline = <<-SHELL
      grep -qxF "#{ssh_pub_key}" /home/vagrant/.ssh/authorized_keys || echo "#{ssh_pub_key}" >> /home/vagrant/.ssh/authorized_keys
      chmod 600 /home/vagrant/.ssh/authorized_keys
    SHELL
  end

  # Create and configure virtual machines
  (1..vm_count).each do |i|
    config.vm.define "test_vm_#{i}" do |node|
      node.vm.box = vm_box
      node.vm.network "private_network", ip: "192.168.56.#{10 + i}"
      node.vm.provider "virtualbox" do |vb|
        vb.memory = 512
        vb.cpus = 1
      end
      # Set the username to test{i}, where i is the machine number
      node.vm.provision "shell", inline: <<-SHELL
        useradd -m -s /bin/bash test#{i}
        mkdir -p /home/test#{i}/.ssh
        cp /home/vagrant/.ssh/authorized_keys /home/test#{i}/.ssh/
        chown -R test#{i}:test#{i} /home/test#{i}/.ssh
        chmod 700 /home/test#{i}/.ssh
        chmod 600 /home/test#{i}/.ssh/authorized_keys
      SHELL
    end
  end
end
EOF

# Export environment variables for Vagrant
export SSH_KEY_DIR VM_COUNT VM_BOX SSH_KEY_NAME

# Start the virtual machines
echo "Starting the virtual machines..."
vagrant up --parallel --no-color --no-tty

# Check the status of the virtual machines
for i in $(seq 1 $VM_COUNT); do
  if ! vagrant status "test_vm_$i" | grep -q "running"; then
    echo "Warning: test_vm_$i did not start correctly."
    exit 1
  fi
done

# Display the private IPs and connection examples
echo "IP addresses of the virtual machines:"
for i in $(seq 1 $VM_COUNT); do
  echo "test_vm_$i: 192.168.56.$((10 + i))"
done
echo "Example to connect: ssh test1@192.168.56.11 -i $SSH_KEY_DIR/$SSH_KEY_NAME"
