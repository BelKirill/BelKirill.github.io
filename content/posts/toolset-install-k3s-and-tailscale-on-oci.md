+++
title = "Setting up a k3s Cluster on a Brand New OCI Instance: A Step-by-Step Guide"
date = "2025-05-28"
+++

When you’re tinkering with AI pair programming or hacking away at your next project, spinning up a robust, lightweight Kubernetes cluster can really level up your game. In this guide, I’ll walk you through setting up a k3s cluster on a fresh Oracle Cloud Infrastructure (OCI) instance, using Tailscale for secure networking and tweaking the config to make it all work seamlessly from your local machine.

Let’s roll up our sleeves and get this k3s cluster humming!

## 1️⃣ Update and Upgrade Your OCI Instance
First things first, ensure your OCI instance is up-to-date. Connect via SSH and run:
```bash
sudo apt update && sudo apt upgrade -y
```
This updates the package list and upgrades installed packages—best practice before any major software installation.

## 2️⃣ Install k3s
k3s is a super-lightweight Kubernetes distribution, perfect for hobbyists and even production-grade work.

To install it:
```bash
curl -sfL https://get.k3s.io | sh -
```
The script installs k3s and sets up the cluster as a single-node master. After installation, you can check the status:
```bash
sudo kubectl get nodes
```

## 3️⃣ Set Up Tailscale for Secure Networking
Now let’s get Tailscale going—this will let you connect securely to your cluster, no need to open up scary firewall rules.

Install Tailscale:
```bash
curl -fsSL https://tailscale.com/install.sh | sh
sudo tailscale up
```
You’ll be prompted to authenticate via your browser. Once done, your instance will be part of your Tailscale network.

## 4️⃣ Connect Your Local Machine to the Cluster
To manage your k3s cluster from your local machine, you need the kubeconfig file from the server.

On the server:
```bash
sudo cat /etc/rancher/k3s/k3s.yaml
```
Copy the file’s content. On your local machine, create or edit:
```bash
~/.kube/config
```
Paste the content in. But wait! We need to tweak it.

## 5️⃣ Edit kubeconfig to Point to Tailscale IP
Your OCI instance has a Tailscale IP—something like 100.x.y.z.

In your local ~/.kube/config, replace the default server IP (often 127.0.0.1 or internal IP) with the Tailscale IP:
```yaml
server: https://100.x.y.z:6443
```
This tells kubectl to hit the cluster via your secure Tailscale network.
## 6️⃣ Fix k3s TLS SAN for Tailscale
By default, k3s uses its server’s internal IP for TLS verification. If you connect with Tailscale, Kubernetes will complain about a mismatch. Let’s fix that.

On your OCI instance:
```bash
sudo vim /etc/systemd/system/k3s.service.env
```
Add or edit:
```bash
K3S_EXTRA_ARGS="--tls-san=100.x.y.z"
```
Reload systemd and restart k3s:
```bash
sudo systemctl daemon-reload
sudo systemctl restart k3s
```
Now your cluster’s TLS certificates include your Tailscale IP—no more verification errors!

## 7️⃣ Check Everything Works: kubectl get nodes
Finally, let’s see if we’re golden:
```bash
kubectl get nodes
```
If you see your node listed as Ready, congrats! You’ve got a fully functional k3s cluster running on your OCI instance, accessible over Tailscale. 🎉

## ✏️ Final Thoughts
his setup is lightweight, secure, and perfect for personal AI projects, hobby coding, or even small-scale production. Plus, adding this kind of secure remote Kubernetes setup to your toolbox is a neat feather in your DevOps hat—especially for headhunters looking for DevOps engineers who can automate and secure cloud-native environments with flair.

If you’re experimenting with AI pair programming, this k3s + Tailscale combo ensures your cluster is always within reach—without the stress of open ports or unsecured traffic. Give it a spin, and let me know how you go!

*_Happy hacking! 🚀✨_*