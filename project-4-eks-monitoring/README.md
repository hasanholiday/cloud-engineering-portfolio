# Project 4: Kubernetes on EKS with Prometheus & Grafana

## Overview
Deployed a real Amazon EKS cluster with live Prometheus and Grafana monitoring, built entirely on Free Tier-eligible infrastructure. This project doubled as a genuine constraint-engineering exercise: `t3.micro` nodes impose hard limits most tutorials never surface, and working within them — rather than upgrading to bigger, non-Free-Tier instances — produced a more instructive build than a clean, well-resourced deployment would have.

## Architecture
- **Orchestration:** Amazon EKS managed control plane, 2 worker nodes (`t3.micro`)
- **Workload:** Self-healing nginx deployment (2 replicas) proving Kubernetes' core reconciliation loop
- **Observability:** Prometheus (metrics collection) + Grafana (dashboards), both running with persistence disabled and connected via Prometheus as a Grafana data source
- **Access:** `kubectl port-forward` + SSH tunnel to view Grafana locally — no public LoadBalancer provisioned, avoiding unnecessary cost for a same-day demo

## Design Decisions & Trade-offs

**Problem:** Demonstrate real Kubernetes orchestration and monitoring without incurring the cost of production-sized infrastructure — while staying inside an AWS account's Free Tier instance-type restriction, which blocked `t3.medium` and larger types entirely.

**Trade-off — `t3.medium` vs. `t3.micro`:** The original plan used `t3.medium` nodes, but the AWS account's Free Tier restriction rejected them outright (`AsgInstanceLaunchFailures: not eligible for Free Tier`). Switching to `t3.micro` (2 vCPU, 1GB memory, Free Tier-eligible) unblocked the cluster but introduced a much lower ceiling on how many pods each node can run — a real constraint to design around rather than a configuration choice.

**Trade-off — Full `kube-prometheus-stack` vs. minimal Prometheus + Grafana:** The standard, fully-bundled monitoring stack (Alertmanager, node-exporter, kube-state-metrics, Prometheus, Grafana, Pushgateway) was the original plan, but its pod count alone would have exceeded what `t3.micro` nodes could schedule. I installed only the two components needed to prove the observability pattern — Prometheus and Grafana — explicitly disabling the rest, prioritizing a working, evidenced demo over an unusable "complete" install that never schedules.

**Trade-off — Production redundancy vs. available pod capacity:** `t3.micro` nodes hit AWS's ENI-based pod-per-node limit at just 4 pods each — a hard networking ceiling, not a memory or CPU issue. With required system pods (`aws-node`, `kube-proxy`, CoreDNS, metrics-server) already consuming most of that capacity, I scaled CoreDNS and metrics-server down from their default 2 replicas to 1 each, trading production-grade redundancy for the ability to run any application workload at all in this constrained environment. This is a decision I would not make in production — it's a deliberate, documented trade-off specific to a resource-constrained Free Tier demo.

**Trade-off — Persistent storage vs. ephemeral, same-day infrastructure:** Prometheus's default Helm chart requests a PersistentVolumeClaim, which failed since this cluster has no EBS CSI storage provisioner installed (not included by default on a fresh EKS cluster). Rather than installing and configuring the CSI driver for a cluster being torn down the same day, I disabled persistence entirely — the right call for a demo environment, but explicitly not the right call for a real production monitoring stack, where losing all metrics history on pod restart would be unacceptable.

**Trade-off — LoadBalancer vs. port-forward for access:** Provisioning a public-facing AWS Load Balancer to view Grafana would have added ongoing hourly cost and public network exposure for a monitoring dashboard that only needed to be viewed once, briefly, for evidence collection. I used `kubectl port-forward` combined with an SSH tunnel instead — zero additional cost, zero public exposure, at the cost of it only being accessible while actively tunneled in.

## The Debugging Sequence (real, in order)
1. **`t3.medium` nodegroup creation failed** — account-level Free Tier instance-type restriction, confirmed via CloudFormation stack events, not a code or config error
2. **Pod scheduling failed with "Too many pods"** — `t3.micro`'s ENI-based 4-pod-per-node ceiling, confirmed by counting running pods against node capacity
3. **Fixed by scaling down non-essential system pod replicas** (CoreDNS, metrics-server) to free scheduling room
4. **Prometheus server failed to schedule** — `unbound immediate PersistentVolumeClaims`, since no default storage provisioner exists on a fresh EKS cluster
5. **Fixed by disabling Prometheus's persistent volume requirement** for this demo environment
6. **Hit the pod ceiling a second time** — the Pushgateway component hadn't actually been removed by an earlier `helm upgrade`, silently consuming a slot
7. **Fixed by force-deleting the Pushgateway deployment directly**, freeing the final slot Prometheus needed

Each of these was diagnosed from the actual Kubernetes event message (`kubectl describe pod`), not guessed at — a discipline worth naming explicitly in an interview.

## Tools Used
EKS, eksctl, kubectl, Helm, Prometheus, Grafana, Docker (nginx image)

## Compliance Relevance
| Framework | Control Area |
|---|---|
| SOC 2 | Availability monitoring — Grafana dashboards provide real-time visibility into system health |
| NIST 800-53 | System monitoring (SI-4) — Prometheus continuous metrics collection |

## Results
- Real EKS cluster deployed and torn down cleanly on Free Tier-eligible hardware
- Self-healing confirmed live: deleting a running pod triggered automatic replacement within seconds, restoring the desired replica count without manual intervention
- Prometheus and Grafana both confirmed running and connected, with the data source integration verified before teardown
- Full evidence collected (node status, pod status across all namespaces, monitoring stack health) before cleanup
- Complete teardown verified across EKS, CloudFormation, NAT Gateway, and Load Balancer checks — zero orphaned resources, zero ongoing cost

## How to Reproduce
```bash
eksctl create cluster \
  --name portfolio-eks-demo \
  --region us-east-1 \
  --nodegroup-name workers \
  --node-type t3.micro \
  --nodes 2 --nodes-min 2 --nodes-max 2 \
  --managed

kubectl create deployment demo-app --image=nginx --replicas=2

helm install prometheus prometheus-community/prometheus \
  --namespace monitoring --create-namespace \
  --set alertmanager.enabled=false \
  --set kube-state-metrics.enabled=false \
  --set prometheus-node-exporter.enabled=false \
  --set pushgateway.enabled=false \
  --set server.persistentVolume.enabled=false

helm install grafana grafana/grafana \
  --namespace monitoring \
  --set persistence.enabled=false
```
Note: on `t3.micro` or similarly small instance types, expect to scale down CoreDNS/metrics-server replicas to free pod scheduling capacity before the monitoring stack will schedule successfully.

## Notes
This project was deliberately built and torn down in a single session to avoid the ongoing hourly cost of the EKS control plane and worker nodes. The constraints documented here (Free Tier instance restrictions, pod-per-node ceilings, missing default storage provisioners) are specific to a cost-conscious portfolio build — a production deployment would use larger instance types, a properly configured EBS CSI driver, and full-redundancy system pod replica counts.
