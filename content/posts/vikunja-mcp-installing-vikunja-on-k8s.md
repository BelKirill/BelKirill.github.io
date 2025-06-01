---
title: "Deploying Vikunja on a k3s Cluster as an Example of Planning and Writing Out a Helm Chart"
date: 2025-06-01
draft: false
summary: "Deploying Vikunja using a newly written Helm chart. A step by step guide."
description: "Learn how to write a Helm chart by learning how I deployed Vikunja on my k3s cluster."
tags: ["helm", "cd", "vikunja-mcp"]
categories: ["DevOps", "vikunja-mcp"]
---

# Deploying Vikunja on a k3s Cluster: A Practical Helm Chart Walkthrough

In this post, I'll share how I set up Vikunja—a popular self-hosted task management application—on a brand new k3s cluster. This journey was more than just a deployment; it became an opportunity to craft a custom Helm chart from scratch. Whether you're a DevOps professional or simply looking to expand your Kubernetes knowledge, this guide is packed with clear step-by-step instructions and personal insights.

> **Note:** This guide assumes you are familiar with Kubernetes basics and Helm installations.

## 1. Setting Up the Stage: Documentation and Planning

Before diving into code, I made sure all my documentation tabs were open. I reviewed the Vikunja environment variables, understanding what each setting controls. This groundwork was essential—it helped me document the parameters that would eventually live in a `values.yaml` file.

### Preparing the Values File

I planned out the installation by creating a comprehensive `values.yaml` file. Here’s a breakdown of my planning process:

* **Feature Flags:** Features like `persistence.enabled` were toggled to easily control aspects such as volume persistence.
* **Components Considered:**
  * **Ingress:** Ensuring external access through Traefik, as k3s provides built-in support.
  * **Postgres DB:** Configuring a Postgres deployment to serve as the backend database.
  * **Volume Mounts:** Ensuring a persistent volume for attachments and user data.
  
I decided to store environment variables in a **ConfigMap** and sensitive data in **Secrets** for maximum security and clarity.

```yaml
# Default values for Vikunja.

nameOverride: ""
fullnameOverride: ""

db:
  type: postgres
  host: vikunja-postgres
  database: vikunja
  user: vikunja
  password: vikunja

  image:
    repository: postgres
    tag: "15"
    pullPolicy: IfNotPresent

  port: 5432
  servicePort: 5432

  resources:
    requests:
      cpu: 200m
      memory: 256Mi
    limits:
      cpu: 500m
      memory: 1Gi

  persistence:
    enabled: true
    size: 20Gi



vikunja:
  name: vikunja
  host: host.domain

  image: 
    repository: vikunja/vikunja
    pullPolicy: IfNotPresent 
    # Overrides the image tag whose default is the chart appVersion.
    tag: "latest"

  replicas: 1

  port: 3456
  servicePort: 3456

  labels: {}
  matchLabels: {}

  resources:
    requests:
      cpu: 200m
      memory: 256Mi
    limits:
      cpu: 500m
      memory: 1Gi

  persistence:
    enabled: true
    volumeSize: 10Gi

  config:
    timezone: "Asia/Jerusalem"
    registrationEnabled: false

smtp:
  enabled: true
  host: smtp.host.com
  port: 587
  user: vikunja
  password: vikunja
  fromEmail: vikunja@host.domain
  skipTLS: false
```
"Wait! You have secrets in the values file!" - Valid point, but I always pull in the real values when templating the helm chart, this is out of scope for this tutorial.
## 2. Installing Prerequisites: Cert Manager

Cert Manager is a must-have for the certificate management in our cluster, especially for securing our ingress with TLS. I deployed Cert Manager using its Helm chart with the following command:

```bash
helm repo add jetstack https://charts.jetstack.io
helm repo update
helm install cert-manager jetstack/cert-manager --namespace cert-manager --create-namespace --set installCRDs=true
```

After the installation, I created a ClusterIssuer to automate certificate issuance:

```yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: youremail@example.com
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
    - http01:
        ingress:
          class: traefik
```

> **Tip:** Always validate that your cert-manager installation is operational by checking its pods and logs.

## 3. Developing the Helm Chart Iteratively

I approached Helm development methodically: write, lint, template, and test. 

### Step-by-Step Approach

#### a. Define the Postgres StatefulSet and Service

I began by coding the Postgres resources. Using a StatefulSet was key to ensuring data persistence and stable network identities.

```yaml
# templates/postgres/statefulset.yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: vikunja-postgres
  labels:
    app: vikunja-postgres
spec:
  selector:
    matchLabels:
      app: vikunja-postgres
  serviceName: "vikunja-postgres"
  replicas: 1
  template:
    metadata:
      labels:
        app: vikunja-postgres
    spec:
      containers:
        - name: postgres
          image: "{{ .Values.db.image.repository }}:{{ .Values.db.image.tag }}"
          ports:
            - containerPort: {{ .Values.db.port }}
          env:
            - name: POSTGRES_DB
              value: {{ .Values.db.database | quote }}
            - name: POSTGRES_USER
              value: {{ .Values.db.user | quote }}
            - name: POSTGRES_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: vikunja-secret
                  key: VIKUNJA_DATABASE_PASSWORD
          volumeMounts:
            - name: postgres-data
              mountPath: /var/lib/postgresql/data
  volumeClaimTemplates:
    - metadata:
        name: postgres-data
      spec:
        accessModes: ["ReadWriteOnce"]
        resources:
          requests:
            storage: {{ .Values.db.persistence.size }}
---
# templates/postgres/service.yaml
apiVersion: v1
kind: Service
metadata:
  name: vikunja-postgres
  labels:
    app: vikunja-postgres
spec:
  type: ClusterIP
  ports:
    - port: {{ .Values.db.servicePort }}
      targetPort: {{ .Values.db.port }}
      protocol: TCP
      name: postgres
  selector:
    app: vikunja-postgres
```

#### b. Creating the Vikunja Deployment, Service, ConfigMap, and Secret

Next, I turned my attention to the Vikunja application itself.

```yaml
# templates/vikunja/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: vikunja
  labels:
    app: vikunja
spec:
  replicas: {{ .Values.vikunja.replicas }}
  selector:
    matchLabels:
      app: vikunja
  template:
    metadata:
      labels:
        app: vikunja
    spec:
      containers:
        - name: vikunja
          image: "{{ .Values.vikunja.image.repository }}:{{ .Values.vikunja.image.tag }}"
          imagePullPolicy: {{ .Values.vikunja.image.pullPolicy }}
          ports:
            - name: http
              containerPort: {{ .Values.vikunja.port }}
              protocol: TCP
          envFrom:
            - configMapRef:
                name: vikunja-config
            - secretRef:
                name: vikunja-secret
          resources:
            requests:
              memory: {{ .Values.vikunja.resources.requests.memory }}
              cpu: {{ .Values.vikunja.resources.requests.cpu }}
            limits:
              memory: {{ .Values.vikunja.resources.limits.memory }}
              cpu: {{ .Values.vikunja.resources.limits.cpu }}
          {{- if .Values.vikunja.persistence.enabled }}
          volumeMounts:
            - name: vikunja-data
              mountPath: /app/vikunja/files
          {{- end }}
{{- if .Values.vikunja.persistence.enabled }}
      volumes:
        - name: vikunja-data
          persistentVolumeClaim:
            claimName: vikunja-data-pvc
{{- end }}

---
# templates/vikunja/service.yaml
apiVersion: v1
kind: Service
metadata:
  name: vikunja
  labels:
    app: vikunja
spec:
  type: ClusterIP
  ports:
    - port: {{ .Values.vikunja.servicePort }}
      targetPort: {{ .Values.vikunja.port }}
      protocol: TCP
      name: http
  selector:
    app: vikunja

```

For managing configuration, I set up a `ConfigMap` and a `Secret`:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: vikunja-config
  labels:
    app: vikunja
data:
  VIKUNJA_DATABASE_TYPE: {{ .Values.db.type | quote }}
  VIKUNJA_DATABASE_HOST: {{ .Values.db.host | quote }}
  VIKUNJA_DATABASE_USER: {{ .Values.db.user | quote }}
  VIKUNJA_DATABASE_DATABASE: {{ .Values.db.database | quote }}

  VIKUNJA_SERVICE_PUBLICURL: {{ .Values.vikunja.host | quote }}
  VIKUNJA_SERVICE_TIMEZONE: {{ .Values.vikunja.config.timezone | quote }}
  VIKUNJA_SERVICE_ENABLEREGISTRATION: {{ .Values.vikunja.config.registrationEnabled | quote }}

  VIKUNJA_MAILER_ENABLED: {{ .Values.smtp.enabled | quote }}
  VIKUNJA_MAILER_HOST: {{ .Values.smtp.host | quote }}
  VIKUNJA_MAILER_PORT: {{ .Values.smtp.port | quote }}
  VIKUNJA_MAILER_USERNAME: {{ .Values.smtp.user | quote }}
  VIKUNJA_MAILER_FROM_EMAIL: {{ .Values.smtp.fromEmail | quote }}
  VIKUNJA_MAILER_SKIP_TLS_VERIFY: {{ .Values.smtp.skipTLS | quote }}

# templates/vikunja/secret.yaml
apiVersion: v1
kind: Secret
metadata:
  name: vikunja-secret
  labels:
    app: vikunja
type: Opaque
data:
  VIKUNJA_DATABASE_PASSWORD: {{ .Values.db.password | b64enc | quote }}
  VIKUNJA_MAILER_PASSWORD: {{ .Values.smtp.password | b64enc | quote }}
```

#### c. Adding Persistent Storage

Attachments need persistence. I added a PersistentVolumeClaim (PVC) and ensured it was mounted in the Vikunja deployment.

```yaml
# templates/vikunja/pvc.yaml
{{- if .Values.vikunja.persistence.enabled -}}
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: vikunja-data-pvc
  labels:
    app: vikunja
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: {{ .Values.vikunja.persistence.volumeSize }}
{{- end}}
```

The PVC is then referenced in the Vikunja deployment under `volumeMounts` as shown earlier.

#### d. Configuring Ingress with Traefik

Since k3s comes with Traefik as the default ingress controller, adding an ingress rule is straightforward:

```yaml
# templates/vikunja/ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: vikunja-ingress
  labels:
    app: vikunja
  annotations:
    # Tell cert-manager to manage the certificate
    cert-manager.io/cluster-issuer: letsencrypt-prod
    # Traefik-specific entrypoint
    traefik.ingress.kubernetes.io/router.entrypoints: websecure
spec:
  rules:
    - host: {{ .Values.vikunja.host }}
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: vikunja
                port:
                  number: {{ .Values.vikunja.servicePort }}
  tls:
    - hosts:
        - {{ .Values.vikunja.host }}
      secretName: vikunja-tls
```

> **Caution:** Ensure the domain names, TLS secrets, and ingress configurations correctly reflect your environment.

#### e. Final Step: Launching Vikunja

After thorough linting (`helm lint .`), templating (`helm template .`), and testing, I deployed my chart:

```bash
helm install vikunja ./my-vikunja-chart
```

Monitor the rollout with:

```bash
kubectl get pods,svc -l app=vikunja
```

Ensure everything is up and running before celebrating!

## 4. Lessons Learned and Final Thoughts

This project was an excellent exercise in planning and iterative development. I continuously refined my Helm chart with a focus on modularity and readability. Here are a few takeaways:

* **Document Everything:** I made sure to have all reference materials ready, reducing guesswork during deployment.
* **Modular Design:** Separating components (like Postgres and Vikunja) helped maintain clarity.
* **Iterative Testing:** Helm linting, templating, and incremental tests ensured a smoother rollout.

As a DevOps engineer who enjoys solving complex deployment puzzles, I find that a well-documented, step-by-step methodology not only enhances reliability but strengthens my technical story when connecting with headhunters and peers alike.

## 5. Conclusion and Next Steps

In this blog post, we walked through the deployment of Vikunja on a k3s cluster using a custom Helm chart. By writing clear and modular configurations for Postgres, Vikunja, PVCs, and Ingress, we created a robust setup ready for production-level usage.

As a next step, consider:
* Scaling the deployment for high availability.
* Adding monitoring and logging solutions.
* Experimenting with CI/CD integrations like GitHub Actions or ArgoCD.

I hope this guide serves as a useful reference for your next Kubernetes project. Happy deploying!
```
