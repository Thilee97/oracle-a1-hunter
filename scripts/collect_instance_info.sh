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

[[ -n "$INSTANCE_ID" && "$INSTANCE_ID" != "null" ]] || {
  echo "::error::Unable to resolve the instance OCID."
  exit 1
}

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

AD="$(python3 - <<'PY'
import json
d=json.load(open("instance.json"))
print((d.get("data") or {}).get("availability-domain") or "")
PY
)"
BOOT_VOLUME_ID="$(
  oci compute boot-volume-attachment list \
    --availability-domain "$AD" \
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

def d(path):
    try:
        return (json.load(open(path)) or {}).get("data") or {}
    except Exception:
        return {}

inst, vnic, image, boot = d("instance.json"), d("vnic.json"), d("image.json"), d("boot_volume.json")

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
    },
    "network": {
        "vnic_id": vnic.get("id"),
        "subnet_id": vnic.get("subnet-id"),
        "private_ip": vnic.get("private-ip"),
        "public_ip": vnic.get("public-ip"),
        "hostname_label": vnic.get("hostname-label"),
        "fqdn": vnic.get("fqdn"),
        "mac_address": vnic.get("mac-address"),
        "nsg_ids": vnic.get("nsg-ids"),
    },
    "image": {
        "id": image.get("id"),
        "display_name": image.get("display-name"),
        "operating_system": image.get("operating-system"),
        "operating_system_version": image.get("operating-system-version"),
        "architecture": image.get("architecture"),
    },
    "boot_volume": {
        "id": boot.get("id"),
        "display_name": boot.get("display-name"),
        "lifecycle_state": boot.get("lifecycle-state"),
        "size_in_gbs": boot.get("size-in-gbs"),
        "vpus_per_gb": boot.get("vpus-per-gb"),
        "time_created": boot.get("time-created"),
    },
    "security_note": "No OCI API private key, SSH private key, Telegram token, or GitHub secrets included."
}

sc = details["instance"].get("shape_config") or {}
ocpus = sc.get("ocpus") or os.environ.get("OCI_OCPUS") or "?"
memory = sc.get("memory-in-gbs") or os.environ.get("OCI_MEMORY_GB") or "?"
public_ip = details["network"].get("public_ip") or "Chưa có / không được gán"
private_ip = details["network"].get("private_ip") or "N/A"
image_name = details["image"].get("display_name") or details["instance"].get("image_id") or "N/A"
boot_size = details["boot_volume"].get("size_in_gbs")
boot_text = f"{boot_size} GB" if boot_size is not None else "N/A"

os_name = (details["image"].get("operating_system") or "").lower()
image_name_l = (details["image"].get("display_name") or "").lower()
if "ubuntu" in os_name or "ubuntu" in image_name_l or "canonical" in image_name_l:
    ssh_user = "ubuntu"
elif "oracle linux" in os_name or "oracle linux" in image_name_l:
    ssh_user = "opc"
else:
    ssh_user = "CHECK_IMAGE_USER"

if details["network"].get("public_ip"):
    user = ssh_user if ssh_user != "CHECK_IMAGE_USER" else "<user>"
    ssh_command = f"ssh -i ~/.ssh/oracle_a1 {user}@{details['network']['public_ip']}"
else:
    ssh_command = "Public IP chưa sẵn sàng."

details["ssh"] = {
    "recommended_user": ssh_user,
    "local_private_key_path": "~/.ssh/oracle_a1",
    "command": ssh_command,
}

Path("vps_details.json").write_text(json.dumps(details, ensure_ascii=False, indent=2), encoding="utf-8")

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
    f"Image: {image_name}",
    f"Boot Volume: {boot_text}",
    f"Created: {details['instance'].get('time_created') or 'N/A'}",
    "",
    "🔑 SSH",
    f"User: {ssh_user}",
    "Private key trên máy bạn: ~/.ssh/oracle_a1",
    f"Lệnh đăng nhập: {ssh_command}",
    "",
    f"Instance OCID: {details['instance'].get('id') or 'N/A'}",
    f"VNIC OCID: {details['network'].get('vnic_id') or 'N/A'}",
    f"Subnet OCID: {details['network'].get('subnet_id') or 'N/A'}",
    f"Boot Volume OCID: {details['boot_volume'].get('id') or 'N/A'}",
    "",
    "📎 vps_details.json chứa thông tin chi tiết.",
    "🔐 Không bao gồm private key/API secret/Telegram token."
]
Path("vps_summary.txt").write_text("\n".join(lines), encoding="utf-8")
PY

cat vps_summary.txt
