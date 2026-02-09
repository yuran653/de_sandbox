# Spark Cluster Resource Allocation

This document describes the resource allocation for the Spark cluster
and Jupyter Notebook running on a VPS with **2 CPUs** and **4GB RAM**.

## Target Configuration
- **1x Spark Master** - Cluster coordinator
- **2x Spark Workers** - Task executors
- **1x Jupyter Notebook** - Web UI for interactive development

## VPS Hardware Profile
- **CPU**: 2 Cores (2000m)
- **RAM**: 4GB (~4096Mi)
- **OS**: Debian 12

## Service Allocation (Kubernetes / K3s)

| Service | CPU Req | CPU Lim | Mem Req | Mem Lim | Notes |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Spark Master** | 250m | 350m | 512Mi | 700Mi | Coordinator |
| **Spark Worker 1** | 475m | 650m | 1024Mi | 1400Mi | Executor, 1GB |
| **Spark Worker 2** | 475m | 650m | 1024Mi | 1400Mi | Executor, 1GB |
| **Jupyter** | 200m | 250m | 512Mi | 800Mi | Web UI + Driver |
| **K3s Reserves** | 200m | - | 512Mi | - | System overhead |
| **TOTAL** | **1600m** | **1900m** | **3472Mi** | **4300Mi** | |

## Resource Utilization Summary
- **CPU Requested**: 80% (1600m / 2000m)
- **CPU Limit**: 95% (1900m / 2000m)
- **Memory Requested**: ~85% (3472Mi / 4096Mi)
- **Memory Limit**: ~105% (4300Mi / 4096Mi) - Overcommitted

## Remaining Capacity
- **CPU Available**: 400m request headroom, 100m limit headroom
- **Memory Available**: ~624Mi request headroom, -204Mi limit (overcommitted)

## Notes
- Each worker allocated 1GB memory for meaningful Spark workloads
- Resources maximized to target 80% request / 95% limit utilization
- Minimal headroom remaining - avoid additional workloads on this node
- K3s system reservation ensures cluster stability
