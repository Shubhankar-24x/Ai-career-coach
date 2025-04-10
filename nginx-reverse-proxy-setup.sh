#!/bin/bash

##########################################
# 1. Increase File Descriptor Limit
##########################################
increase_fd_limit() {
    echo "📌 Checking current file descriptor limits..."

    CURRENT_LIMIT=$(ulimit -n)
    MAX_LIMIT=100000

    if [ "$CURRENT_LIMIT" -ge "$MAX_LIMIT" ]; then
        echo "✅ Current file descriptor limit ($CURRENT_LIMIT) is already sufficient."
    else
        echo "❌ Current file descriptor limit ($CURRENT_LIMIT) is too low. Increasing it..."
        ulimit -n $MAX_LIMIT || { echo "❌ Failed to increase file descriptor limit. Exiting..."; exit 1; }
        NEW_LIMIT=$(ulimit -n)
        if [ "$NEW_LIMIT" -eq "$MAX_LIMIT" ]; then
            echo "✅ File descriptor limit increased to $NEW_LIMIT."
        else
            echo "❌ Failed to set the file descriptor limit. Exiting..."
            exit 1
        fi
    fi
}

make_fd_limit_persistent() {
    echo "📌 Making file descriptor limit persistent..."

    echo "* soft nofile 100000" | sudo tee -a /etc/security/limits.conf
    echo "* hard nofile 100000" | sudo tee -a /etc/security/limits.conf

    if ! grep -q "session required pam_limits.so" /etc/pam.d/common-session; then
        echo "session required pam_limits.so" | sudo tee -a /etc/pam.d/common-session
    fi

    if ! grep -q "fs.file-max = 100000" /etc/sysctl.conf; then
        echo "fs.file-max = 100000" | sudo tee -a /etc/sysctl.conf
    fi

    echo "📌 Reloading sysctl settings..."
    sudo sysctl -p || { echo "❌ Failed to reload sysctl settings. Exiting..."; exit 1; }

    echo "✅ File descriptor limits made persistent and sysctl settings reloaded."
}

apply_fd_limit_for_user() {
    echo "📌 Applying file descriptor limits for the user..."

    if [ -f /etc/systemd/system/kubelet.service.d/10-kubeadm.conf ]; then
        echo "📌 Updating kubelet service configuration..."
        sudo sed -i 's/Environment="KUBELET_EXTRA_ARGS=--max-pods=110"/Environment="KUBELET_EXTRA_ARGS=--max-pods=110 --file-max=100000"/' /etc/systemd/system/kubelet.service.d/10-kubeadm.conf
        sudo systemctl daemon-reload
        sudo systemctl restart kubelet
    else
        echo "📌 Updating user limits..."
        echo "* soft nofile 100000" | sudo tee -a /etc/security/limits.conf
        echo "* hard nofile 100000" | sudo tee -a /etc/security/limits.conf
    fi
}

##########################################
# 2. Nginx Reverse Proxy + Ingress Setup
##########################################
setup_nginx_and_ingress() {
    echo "🚀 Setting up Nginx as a Reverse Proxy for your Kind application..."

    read -p "Enter the application namespace: " NAMESPACE
    echo "✅ Namespace confirmed: $NAMESPACE"

    SERVICE_NAME=$(kubectl get svc -n "$NAMESPACE" -o jsonpath='{.items[0].metadata.name}')
    [ -z "$SERVICE_NAME" ] && echo "❌ Service not found in namespace $NAMESPACE. Exiting..." && exit 1
    echo "✅ Service detected: $SERVICE_NAME"

    PORT=$(kubectl get svc "$SERVICE_NAME" -n "$NAMESPACE" -o jsonpath='{.spec.ports[0].port}')
    [ -z "$PORT" ] && echo "❌ Service port not found. Exiting..." && exit 1
    echo "✅ Using port: $PORT"

    KIND_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[0].address}')
    PUBLIC_IP=$(curl -s ifconfig.me)
    HOSTNAME="${PUBLIC_IP}.nip.io"

    echo "✅ Kind IP: $KIND_IP"
    echo "✅ Public IP: $PUBLIC_IP"
    echo "✅ Hostname: $HOSTNAME"

    if ! command -v nginx &> /dev/null; then
        echo "❌ Nginx is not installed. Installing..."
        sudo apt update && sudo apt install -y nginx || exit 1
    fi
    sudo rm -f /etc/nginx/sites-enabled/default
    sudo systemctl restart nginx

    if ! kubectl get ns ingress-nginx &> /dev/null; then
        echo "📌 Installing Ingress Nginx Controller..."
        kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml || exit 1
    fi

    echo "⏳ Waiting for Ingress Controller to be ready..."

    kubectl wait --namespace ingress-nginx \
      --for=condition=Available \
      deployment/ingress-nginx-controller \
      --timeout=180s || { echo "❌ Timeout waiting for Ingress Controller. Exiting..."; exit 1; }

    echo "⏳ Verifying all ingress-nginx-controller pods are running..."
    while true; do
        NOT_READY=$(kubectl get pods -n ingress-nginx -l app.kubernetes.io/component=controller \
          -o jsonpath='{.items[*].status.containerStatuses[*].ready}' | grep -cv true)
        [ "$NOT_READY" -eq 0 ] && break
        echo "⌛ Waiting for all ingress-nginx-controller pods to be ready..."
        sleep 5
    done

    echo "✅ All Ingress Controller pods are ready."

    if ! kubectl get pod -n ingress-nginx | grep -q ingress-nginx-controller; then
        echo "📌 Patching ingress controller to remove affinity..."
        kubectl patch deployment ingress-nginx-controller -n ingress-nginx \
          --patch '{"spec":{"template":{"spec":{"affinity":null}}}}' || exit 1
    fi

    echo "📌 Creating Ingress resource..."
    cat <<EOF | kubectl apply -n "$NAMESPACE" -f - --validate=false
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: ${SERVICE_NAME}-ingress
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  ingressClassName: nginx
  rules:
  - host: $HOSTNAME
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: $SERVICE_NAME
            port:
              number: $PORT
EOF

    INGRESS_PORT=$(kubectl get svc ingress-nginx-controller -n ingress-nginx -o jsonpath='{.spec.ports[0].nodePort}')
    sudo ufw allow "$INGRESS_PORT"/tcp

    echo "📌 Setting up Nginx reverse proxy..."
    cat <<EOF | sudo tee /etc/nginx/sites-available/reverse-proxy.conf
server {
    listen 80;
    server_name $HOSTNAME;

    location / {
        proxy_pass http://$KIND_IP:$INGRESS_PORT;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF

    sudo rm -f /etc/nginx/sites-enabled/reverse-proxy.conf
    sudo ln -s /etc/nginx/sites-available/reverse-proxy.conf /etc/nginx/sites-enabled/
    sudo systemctl restart nginx

    echo "✅ Setup complete. Access your app at: http://$HOSTNAME"
}

##########################################
# Run All Steps
##########################################
increase_fd_limit
make_fd_limit_persistent
apply_fd_limit_for_user
setup_nginx_and_ingress
