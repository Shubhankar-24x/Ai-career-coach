#!/bin/bash

echo "🚀 Setting up Nginx as a Reverse Proxy for your Kind application..."

# Get the namespace
read -p "Enter the application namespace: " NAMESPACE
echo "✅ Namespace confirmed: $NAMESPACE"

# Get the service name
SERVICE_NAME=$(kubectl get svc -n "$NAMESPACE" -o jsonpath='{.items[0].metadata.name}')
if [ -z "$SERVICE_NAME" ]; then
    echo "❌ Service not found in namespace $NAMESPACE. Exiting..."
    exit 1
fi
echo "✅ Service detected: $SERVICE_NAME"

# Get the service port
PORT=$(kubectl get svc "$SERVICE_NAME" -n "$NAMESPACE" -o jsonpath='{.spec.ports[0].port}')
if [ -z "$PORT" ]; then
    echo "❌ Service port not found. Exiting..."
    exit 1
fi
echo "✅ Using port: $PORT"

# Get the Kind Cluster Node IP
KIND_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[0].address}')
if [ -z "$KIND_IP" ]; then
    echo "❌ Could not retrieve Kind Cluster Node IP. Exiting..."
    exit 1
fi
echo "✅ Kind Cluster Node IP detected: $KIND_IP"

# Get the public IP of the server
PUBLIC_IP=$(curl -s ifconfig.me)
if [ -z "$PUBLIC_IP" ]; then
    echo "❌ Could not retrieve server public IP. Exiting..."
    exit 1
fi
echo "✅ Server Public IP detected: $PUBLIC_IP"

# Generate hostname using nip.io
HOSTNAME="${PUBLIC_IP}.nip.io"
echo "✅ Using hostname for Ingress: $HOSTNAME"

# Ensure Nginx is installed
if ! command -v nginx &> /dev/null; then
    echo "❌ Nginx is not installed. Installing..."
    sudo apt update && sudo apt install -y nginx || { echo "❌ Nginx installation failed. Exiting..."; exit 1; }
fi
echo "✅ Nginx is installed."

# Remove any default Nginx configuration
echo "📌 Removing default Nginx configuration..."
sudo rm -rf /etc/nginx/sites-enabled/default || { echo "❌ Failed to remove default Nginx configuration. Exiting..."; exit 1; }
sudo systemctl restart nginx || { echo "❌ Failed to restart Nginx. Exiting..."; exit 1; }

# Check if the Ingress Nginx controller is installed
if ! kubectl get ns ingress-nginx &> /dev/null; then
    echo "❌ Nginx Ingress Controller not found. Installing..."
    kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml || { echo "❌ Failed to install Ingress Nginx controller. Exiting..."; exit 1; }
    sleep 10
else
    echo "✅ Ingress Nginx Controller is already installed."
fi

# Ensure the Ingress Nginx controller is scheduled
echo "📌 Checking if Nginx Ingress controller can be scheduled..."

# Check if worker nodes have the label for Ingress scheduling
WORKER_NODES=$(kubectl get nodes --show-labels | grep 'ingress-ready=true')
if [ -z "$WORKER_NODES" ]; then
    echo "❌ No nodes labeled with ingress-ready=true. Labeling a worker node..."
    kubectl label nodes kind-worker ingress-ready=true || { echo "❌ Failed to label worker node. Exiting..."; exit 1; }
else
    echo "✅ Worker node labeled with ingress-ready=true found."
fi

# Alternatively, if no node can be found, patch the deployment to remove affinity
if ! kubectl get pod -n ingress-nginx | grep -q ingress-nginx-controller; then
    echo "❌ Ingress controller pod is not running, patching deployment to remove affinity..."
    kubectl patch deployment ingress-nginx-controller -n ingress-nginx \
      --patch '{"spec":{"template":{"spec":{"affinity":null}}}}' || { echo "❌ Failed to patch deployment. Exiting..."; exit 1; }
fi

# Wait for the Ingress Controller to be ready
echo "⏳ Waiting for Ingress Controller to be ready..."
kubectl wait --namespace ingress-nginx \
  --for=condition=available deployment/ingress-nginx-controller \
  --timeout=180s || { echo "❌ Ingress controller did not become ready in time. Exiting..."; exit 1; }

# Check if the webhook is ready (for validation)
WEBHOOK_READY=$(kubectl get svc ingress-nginx-controller-admission -n ingress-nginx -o jsonpath='{.spec.clusterIP}')
if [ -z "$WEBHOOK_READY" ]; then
    echo "❌ Webhook service is not ready. Retrying..."
    sleep 10
    kubectl apply -n "$NAMESPACE" -f - --validate=false || { echo "❌ Failed to apply Ingress without validation. Exiting..."; exit 1; }
else
    echo "✅ Webhook service is ready."
    # Retry to apply Ingress with validation
    echo "📌 Creating Ingress for application..."
    cat <<EOF | kubectl apply -n "$NAMESPACE" -f - --validate=false || { echo "❌ Failed to create Ingress. Exiting..."; exit 1; }
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
fi

# Ensure the NodePort is available for the Ingress controller
echo "📌 Checking Ingress Controller NodePort..."
INGRESS_PORT=$(kubectl get svc ingress-nginx-controller -n ingress-nginx -o jsonpath='{.spec.ports[0].nodePort}')
if [ -z "$INGRESS_PORT" ]; then
    echo "❌ NodePort not found. Exiting..."
    exit 1
fi
echo "✅ NodePort for Ingress Controller is: $INGRESS_PORT"

# Ensure the server firewall allows traffic on the NodePort
echo "📌 Ensuring firewall allows traffic on NodePort $INGRESS_PORT..."
if ! sudo ufw status | grep -q "$INGRESS_PORT"; then
    echo "❌ Firewall rule for NodePort $INGRESS_PORT not found. Adding rule..."
    sudo ufw allow $INGRESS_PORT/tcp || { echo "❌ Failed to add firewall rule. Exiting..."; exit 1; }
fi

# Set up the Nginx reverse proxy configuration
echo "📌 Setting up Nginx reverse proxy configuration..."
cat <<EOF | sudo tee /etc/nginx/sites-available/reverse-proxy.conf || { echo "❌ Failed to write Nginx config. Exiting..."; exit 1; }
server {
    listen 80;
    server_name $HOSTNAME;

    location / {
        proxy_pass http://$KIND_IP:$INGRESS_PORT;  # Proxy to the Ingress Controller's NodePort
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF

# Remove the existing symlink if it exists
if [ -L /etc/nginx/sites-enabled/reverse-proxy.conf ]; then
    echo "📌 Removing existing symlink for reverse-proxy.conf..."
    sudo rm /etc/nginx/sites-enabled/reverse-proxy.conf || { echo "❌ Failed to remove existing symlink. Exiting..."; exit 1; }
fi

# Enable the reverse proxy configuration in Nginx
echo "📌 Enabling Nginx reverse proxy configuration..."
sudo ln -s /etc/nginx/sites-available/reverse-proxy.conf /etc/nginx/sites-enabled/ || { echo "❌ Failed to enable Nginx reverse proxy configuration. Exiting..."; exit 1; }

# Restart Nginx to apply the configuration
echo "📌 Restarting Nginx to apply the new configuration..."
sudo systemctl restart nginx || { echo "❌ Failed to restart Nginx. Exiting..."; exit 1; }

# Verify if the Ingress is created successfully
echo "✅ Ingress created. Access your application at: http://$HOSTNAME"