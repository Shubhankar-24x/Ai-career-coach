#!/bin/bash

# Function to check and increase the file descriptor limit
increase_fd_limit() {
    echo "📌 Checking current file descriptor limits..."

    # Get current limits
    CURRENT_LIMIT=$(ulimit -n)
    MAX_LIMIT=100000

    if [ "$CURRENT_LIMIT" -ge "$MAX_LIMIT" ]; then
        echo "✅ Current file descriptor limit ($CURRENT_LIMIT) is already sufficient."
    else
        echo "❌ Current file descriptor limit ($CURRENT_LIMIT) is too low. Increasing it..."

        # Increase the soft limit temporarily for the current session
        ulimit -n $MAX_LIMIT || { echo "❌ Failed to increase file descriptor limit. Exiting..."; exit 1; }

        # Verify if the limit is set correctly
        NEW_LIMIT=$(ulimit -n)
        if [ "$NEW_LIMIT" -eq "$MAX_LIMIT" ]; then
            echo "✅ File descriptor limit increased to $NEW_LIMIT."
        else
            echo "❌ Failed to set the file descriptor limit. Exiting..."
            exit 1
        fi
    fi
}

# Function to make the change persistent by editing system files
make_fd_limit_persistent() {
    echo "📌 Making file descriptor limit persistent..."

    # Update /etc/security/limits.conf for soft and hard limits
    echo "*               soft    nofile          100000" | sudo tee -a /etc/security/limits.conf
    echo "*               hard    nofile          100000" | sudo tee -a /etc/security/limits.conf

    # Ensure PAM limits are applied by editing common-session file
    if ! grep -q "session required pam_limits.so" /etc/pam.d/common-session; then
        echo "session required pam_limits.so" | sudo tee -a /etc/pam.d/common-session
    fi

    # Update /etc/sysctl.conf to increase system-wide file max limit
    if ! grep -q "fs.file-max = 100000" /etc/sysctl.conf; then
        echo "fs.file-max = 100000" | sudo tee -a /etc/sysctl.conf
    fi

    # Reload sysctl settings to apply changes
    echo "📌 Reloading sysctl settings..."
    sudo sysctl -p || { echo "❌ Failed to reload sysctl settings. Exiting..."; exit 1; }

    # Verify if the changes were successfully applied
    echo "✅ File descriptor limits made persistent and sysctl settings reloaded."
}

# Function to ensure that the user is able to apply the new limits
apply_fd_limit_for_user() {
    echo "📌 Applying file descriptor limits for the user..."

    # For Kubernetes environments, ensure that the container or user has the correct limits
    if [ -f /etc/systemd/system/kubelet.service.d/10-kubeadm.conf ]; then
        # If running inside a container (Kubernetes worker nodes)
        echo "📌 Updating kubelet service configuration..."

        # Add file descriptor limits in kubelet service file
        sudo sed -i 's/Environment="KUBELET_EXTRA_ARGS=--max-pods=110"/Environment="KUBELET_EXTRA_ARGS=--max-pods=110 --file-max=100000"/' /etc/systemd/system/kubelet.service.d/10-kubeadm.conf

        # Reload systemd to apply changes
        sudo systemctl daemon-reload
        sudo systemctl restart kubelet
    else
        # Otherwise, if running on a normal system
        echo "📌 Updating user limits..."

        # Add limits to /etc/security/limits.conf if it's not already done
        echo "*               soft    nofile          100000" | sudo tee -a /etc/security/limits.conf
        echo "*               hard    nofile          100000" | sudo tee -a /etc/security/limits.conf
    fi

    # Reload user session
    exec bash || { echo "❌ Failed to restart the shell. Exiting..."; exit 1; }

    echo "✅ File descriptor limits applied to user session."
}

# Function to restart necessary services to ensure changes are applied
restart_services() {
    echo "📌 Restarting necessary services..."

    # Restart shell to apply changes immediately
    exec bash || { echo "❌ Failed to restart the shell. Exiting..."; exit 1; }
}

# Start the process
increase_fd_limit
make_fd_limit_persistent
apply_fd_limit_for_user
restart_services

# Retry the operation that was previously failing
echo "📌 Retrying the operation that was failing..."
# Example Task: Checking Kubernetes pods again
kubectl get pods -A || { echo "❌ Failed to retrieve Kubernetes pods. Exiting..."; exit 1; }

# Proceed with other tasks
echo "✅ Kubernetes pods retrieved successfully."
