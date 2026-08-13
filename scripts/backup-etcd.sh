#!/usr/bin/env bash
# K8s Backup Script -- daily etcd backup + Velero resources backup
# Run: 0 3 * * * /opt/scripts/backup-etcd.sh
set -euo pipefail

BACKUP_DIR="/var/backups/etcd"
RETENTION_DAYS=30
S3_BUCKET="s3://multi-cloud-prod-etcd-backups"
DATE=$(date +%Y%m%d-%H%M%S)
mkdir -p "$BACKUP_DIR"

echo "=== Backup: $DATE ==="

# Velero backup (all K8s resources + PV snapshots)
if command -v velero &>/dev/null; then
    echo "Running Velero backup..."
    velero backup create "daily-$DATE" \
        --include-namespaces default,production,monitoring \
        --ttl "${RETENTION_DAYS}d" \
        --snapshot-volumes=true --wait
    echo "Velero: daily-$DATE"
    velero backup describe "daily-$DATE"
fi

# Self-managed etcd snapshot (dev/test environments)
if [ -f /etc/kubernetes/manifests/etcd.yaml ]; then
    echo "Self-managed etcd: creating snapshot..."
    ETCDCTL_API=3 etcdctl snapshot save "$BACKUP_DIR/etcd-snapshot-$DATE.db" \
        --endpoints=https://127.0.0.1:2379 \
        --cacert=/etc/kubernetes/pki/etcd/ca.crt \
        --cert=/etc/kubernetes/pki/etcd/server.crt \
        --key=/etc/kubernetes/pki/etcd/server.key

    ETCDCTL_API=3 etcdctl snapshot status "$BACKUP_DIR/etcd-snapshot-$DATE.db"

    # Upload to S3
    aws s3 cp "$BACKUP_DIR/etcd-snapshot-$DATE.db" \
        "$S3_BUCKET/etcd-snapshot-$DATE.db" --storage-class STANDARD_IA

    # Cleanup old backups
    find "$BACKUP_DIR" -name "etcd-snapshot-*.db" -mtime "+$RETENTION_DAYS" -delete
fi

echo "=== Backup complete ==="