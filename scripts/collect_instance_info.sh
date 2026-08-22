#!/usr/bin/env bash
set -euo pipefail

if [[ -z "${INSTANCE_ID:-}" || "$INSTANCE_ID" == "null" ]]; then
  INSTANCE_ID="$(
    oci compute instance list \
      --compartment-id "$OCI_COMPARTMENT_OCID" \
      --display-name "$INSTANCE_NAME" \
      --all \
      --query "data[?\"lifecycle-state\"!='TERMINATED'] | [0].id" \
      --raw-output
  )"
fi

if [[ -z "$INSTANCE_ID" || "$INSTANCE_ID" == "null" ]]; then
  echo "::error::Unable to resolve the instance OCID."
  exit 1
fi

echo "Collecting details for $INSTANCE_ID"

oci compute instance get --instance-id "$INSTANCE_ID" > instance.json

VNIC_ID="$(
  oci compute vnic-attachment list \
    --compartment-id "$OCI_COMPARTMENT_OCID" \
    --instance-id "$INSTANCE_ID" \
    --all \
    --query "data[?\"lifecycle-state\"=='ATTACHED'] | [0].\"vnic-id\"" \
    --raw-output
)"

if [[ -n "$VNIC_ID" && "$VNIC_ID" != "null" ]]; then
  oci network vnic get --vnic-id "$VNIC_ID" > vnic.json
else
  printf '{"data": null}\n' > vnic.json
fi

IMAGE_ID="$(python3 - <<'PY'
import json
d=json.load(open("instance.json"))
print((d.get("data") or {}).get("image-id") or "")
PY
)"

if [[ -n "$IMAGE_ID" ]]; then
  oci compute image get --image-id "$IMAGE_ID" > image.json || printf '{"data": null}\n' > image.json
else
  printf '{"data": null}\n' > image.json
fi

BOOT_VOLUME_ID="$(
  oci compute boot-volume-attachment list \
    --availability-domain "$(python3 - <<'PY'
import json
d=json.load(open("instance.json"))
print((d.get("data") or {}).get("availability-domain") or "")
PY
)" \
    --compartment-id "$OCI_COMPARTMENT_OCID" \
    --instance-id "$INSTANCE_ID" \
    --all \
    --query "data[?\"lifecycle-state\"=='ATTACHED'] | [0].\"boot-volume-id\"" \
    --raw-output 2>/dev/null || true
)"

if [[ -n "$BOOT_VOLUME_ID" && "$BOOT_VOLUME_ID" != "null" ]]; then
  oci bv boot-volume get --boot-volume-id "$BOOT_VOLUME_ID" > boot_volume.json || printf '{"data": null}\n' > boot_volume.json
else
  printf '{"data": null}\n' > boot_volume.json
fi

python3 - <<'PY'
import json, os
from pathlib import Path

def read_data(path):
    try:
        obj = json.load(open(path))
        return obj.get("data")
    except Exception:
        return None

inst = read_data("instance.json") or {}
vnic = read_data("vnic.json") or {}
image = read_data("image.json") or {}
boot = read_data("boot_volume.json") or {}

# Intentionally omit instance metadata because it may contain SSH authorized keys.
details = {
    "instance": {
        "id": inst.get("id"),
        "display_name": inst.get("display-name"),
        "lifecycle_state": inst.get("lifecycle-state"),
        "region": inst.get("region") or os.environ.get("OCI_REGION"),
        "availability_domain": inst.get("availability-domain"),
        "fault_domain": inst.get("fault-domain"),
        "shape": inst.get("shape"),
        "shape_config": inst.get("shape-config"),
        "time_created": inst.get("time-created"),
        "compartment_id": inst.get("compartment-id"),
        "image_id": inst.get("image-id"),
        "launch_mode": inst.get("launch-mode"),
        "is_pv_encryption_in_transit_enabled": inst.get("is-pv-encryption-in-transit-enabled"),
        "freeform_tags": inst.get("freeform-tags"),
        "defined_tags": inst.get("defined-tags"),
    },
    "network": {
        "vnic_id": vnic.get("id"),
        "display_name": vnic.get("display-name"),
        "subnet_id": vnic.get("subnet-id"),
        "private_ip": vnic.get("private-ip"),
        "public_ip": vnic.get("public-ip"),
        "hostname_label": vnic.get("hostname-label"),
        "fqdn": vnic.get("fqdn"),
        "mac_address": vnic.get("mac-address"),
        "nsg_ids": vnic.get("nsg-ids"),
        "skip_source_dest_check": vnic.get("skip-source-dest-check"),
        "is_primary": vnic.get("is-primary"),
    },
    "image": {
        "id": image.get("id"),
        "display_name": image.get("display-name"),
        "operating_system": image.get("operating-system"),
        "operating_system_version": image.get("operating-system-version"),
        "architecture": image.get("architecture"),
        "size_in_mbs": image.get("size-in-mbs"),
        "time_created": image.get("time-created"),
    },
    "boot_volume": {
        "id": boot.get("id"),
        "display_name": boot.get("display-name"),
        "lifecycle_state": boot.get("lifecycle-state"),
        "size_in_gbs": boot.get("size-in-gbs"),
        "vpus_per_gb": boot.get("vpus-per-gb"),
        "is_hydrated": boot.get("is-hydrated"),
        "time_created": boot.get("time-created"),
    },
    "hunter": {
        "requested_ocpus": os.environ.get("OCI_OCPUS"),
        "requested_memory_gb": os.environ.get("OCI_MEMORY_GB"),
        "requested_shape": os.environ.get("OCI_SHAPE"),
        "repository": os.environ.get("GITHUB_REPOSITORY"),
        "run_id": os.environ.get("GITHUB_RUN_ID"),
    },
    "security_note": "OCI API private key, Telegram bot token and other GitHub secrets are intentionally not included."
}

Path("vps_details.json").write_text(
    json.dumps(details, ensure_ascii=False, indent=2),
    encoding="utf-8"
)

sc = details["instance"].get("shape_config") or {}
ocpus = sc.get("ocpus") or details["hunter"]["requested_ocpus"] or "?"
memory = sc.get("memory-in-gbs") or details["hunter"]["requested_memory_gb"] or "?"
public_ip = details["network"].get("public_ip") or "Chưa có / không được gán"
private_ip = details["network"].get("private_ip") or "N/A"
image_name = details["image"].get("display_name") or details["instance"].get("image_id") or "N/A"
boot_size = details["boot_volume"].get("size_in_gbs")
boot_text = f"{boot_size} GB" if boot_size is not None else "N/A"

os_name = (details["image"].get("operating_system") or "").lower()
image_name_l = (details["image"].get("display_name") or "").lower()

if "ubuntu" in os_name or "ubuntu" in image_name_l or "canonical" in image_name_l:
    ssh_user = "ubuntu"
elif "oracle linux" in os_name or "oracle-linux" in image_name_l or "oracle linux" in image_name_l:
    ssh_user = "opc"
else:
    ssh_user = "CHECK_IMAGE_USER"

public_ip_for_ssh = details["network"].get("public_ip")
if public_ip_for_ssh:
    if ssh_user != "CHECK_IMAGE_USER":
        ssh_command = f"ssh -i ~/.ssh/oracle_a1 {ssh_user}@{public_ip_for_ssh}"
    else:
        ssh_command = f"ssh -i ~/.ssh/oracle_a1 <user>@{public_ip_for_ssh}"
else:
    ssh_command = "Public IP chưa sẵn sàng."

details["ssh"] = {
    "recommended_user": ssh_user,
    "local_private_key_path": "~/.ssh/oracle_a1",
    "command": ssh_command,
    "note": "Private SSH key stays on your own computer and is never sent to Telegram."
}

# Rewrite JSON so the SSH helper section is included.
Path("vps_details.json").write_text(
    json.dumps(details, ensure_ascii=False, indent=2),
    encoding="utf-8"
)

lines = [
    "✅ ORACLE VPS ĐÃ TẠO THÀNH CÔNG",
    "",
    f"Name: {details['instance'].get('display_name') or 'N/A'}",
    f"State: {details['instance'].get('lifecycle_state') or 'N/A'}",
    f"Region: {details['instance'].get('region') or 'N/A'}",
    f"Availability Domain: {details['instance'].get('availability_domain') or 'N/A'}",
    f"Fault Domain: {details['instance'].get('fault_domain') or 'N/A'}",
    f"Shape: {details['instance'].get('shape') or 'N/A'}",
    f"CPU: {ocpus} OCPU",
    f"RAM: {memory} GB",
    f"Public IP: {public_ip}",
    f"Private IP: {private_ip}",
    f"Hostname: {details['network'].get('hostname_label') or 'N/A'}",
    f"FQDN: {details['network'].get('fqdn') or 'N/A'}",
    f"Image: {image_name}",
    f"Boot Volume: {boot_text}",
    f"Created: {details['instance'].get('time_created') or 'N/A'}",
    "",
    "🔑 SSH",
    f"User: {ssh_user}",
    f"Private key trên máy bạn: ~/.ssh/oracle_a1",
    f"Lệnh đăng nhập: {ssh_command}",
    "",
    f"Instance OCID: {details['instance'].get('id') or 'N/A'}",
    f"VNIC OCID: {details['network'].get('vnic_id') or 'N/A'}",
    f"Subnet OCID: {details['network'].get('subnet_id') or 'N/A'}",
    f"Boot Volume OCID: {details['boot_volume'].get('id') or 'N/A'}",
    "",
    "📎 File vps_details.json đính kèm chứa thông tin chi tiết.",
    "🔐 Không bao gồm OCI private key, API secret hoặc Telegram token."
]

Path("vps_summary.txt").write_text("\n".join(lines), encoding="utf-8")
PY

cat vps_summary.txt
