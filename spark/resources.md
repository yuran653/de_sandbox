# Spark Cluster Resource Allocation

This document describes the resource allocation for the Spark cluster
and Jupyter Notebook running on a VPS with **4 CPUs** and **8GB RAM**.

## Target Configuration
- **1x Spark Master** - Cluster coordinator
- **2x Spark Workers** - Task executors
- **1x Jupyter Notebook** - Web UI for interactive development

## VPS Hardware Profile
- **CPU**: 4 Cores (4000m)
- **RAM**: 8GB (~8192Mi)
- **OS**: Debian 12

## Service Allocation (Kubernetes / K3s)

| Service | CPU Req | CPU Lim | Mem Req | Mem Lim | Notes |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Spark Master** | 500m | 600m | 1024Mi | 1280Mi | Coordinator |
| **Spark Worker 1** | 1200m | 1400m | 2560Mi | 2816Mi | Executor, 2GB |
| **Spark Worker 2** | 1200m | 1400m | 2560Mi | 2816Mi | Executor, 2GB |
| **Jupyter** | 400m | 500m | 768Mi | 1024Mi | Web UI + Driver |
| **K3s Reserves** | 200m | - | 512Mi | - | System overhead |
| **TOTAL** | **3500m** | **3900m** | **7424Mi** | **7936Mi** | |

## Resource Utilization Summary
- **CPU Requested**: 87.5% (3500m / 4000m)
- **CPU Limit**: 97.5% (3900m / 4000m)
- **Memory Requested**: ~90.6% (7424Mi / 8192Mi)
- **Memory Limit**: ~96.9% (7936Mi / 8192Mi)

## Remaining Capacity
- **CPU Available**: 500m request headroom, 100m limit headroom
- **Memory Available**: ~768Mi request headroom, ~256Mi limit headroom

## Notes
- Each worker allocated 2GB memory for meaningful Spark workloads
- Resources maximized to target ~90% request / ~97% limit utilization
- Minimal headroom remaining - avoid additional workloads on this node
- K3s system reservation ensures cluster stability
