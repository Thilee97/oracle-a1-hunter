#!/usr/bin/env bash
set -euo pipefail

required_vars=(
  OCI_TENANCY_OCID
  OCI_USER_OCID
  OCI_FINGERPRINT
  OCI_REGION
  OCI_COMPARTMENT_OCID
  OCI_SUBNET_OCID
  OCI_IMAGE_OCID
  OCI_SSH_PUBLIC_KEY
  INSTANCE_NAME
  OCI_SHAPE
  OCI_OCPUS
  OCI_MEMORY_GB
)

for var in "${required_vars[@]}"; do
  if [[ -z "${!var:-}" ]]; then
    echo "::error::Missing required variable/secret: $var"
    exit 1
  fi
done

echo "Region: $OCI_REGION"
echo "Target: $OCI_SHAPE, ${OCI_OCPUS} OCPU, ${OCI_MEMORY_GB} GB RAM"
echo "Instance name: $INSTANCE_NAME"

EXISTING_ID="$(
  oci compute instance list \
    --compartment-id "$OCI_COMPARTMENT_OCID" \
    --display-name "$INSTANCE_NAME" \
    --all \
    --query "data[?\"lifecycle-state\"!='TERMINATED'] | [0].id" \
    --raw-output
)"

if [[ -n "$EXISTING_ID" && "$EXISTING_ID" != "null" ]]; then
  echo "An instance named '$INSTANCE_NAME' already exists: $EXISTING_ID"
  {
    echo "exists=true"
    echo "created=false"
    echo "instance_id=$EXISTING_ID"
  } >> "$GITHUB_OUTPUT"
  exit 0
fi

AD="$(
  oci iam availability-domain list \
    --compartment-id "$OCI_TENANCY_OCID" \
    --query "data[0].name" \
    --raw-output
)"

if [[ -z "$AD" || "$AD" == "null" ]]; then
  echo "::error::Could not determine an Availability Domain."
  exit 1
fi

echo "Availability Domain: $AD"

METADATA="$(python3 - <<'PY'
import json, os
print(json.dumps({
    "ssh_authorized_keys": os.environ["OCI_SSH_PUBLIC_KEY"]
}))
PY
)"

set +e
OUTPUT="$(
  oci compute instance launch \
    --availability-domain "$AD" \
    --compartment-id "$OCI_COMPARTMENT_OCID" \
    --subnet-id "$OCI_SUBNET_OCID" \
    --image-id "$OCI_IMAGE_OCID" \
    --shape "$OCI_SHAPE" \
    --shape-config "{\"ocpus\": ${OCI_OCPUS}, \"memoryInGBs\": ${OCI_MEMORY_GB}}" \
    --display-name "$INSTANCE_NAME" \
    --assign-public-ip true \
    --metadata "$METADATA" \
    --wait-for-state RUNNING \
    --max-wait-seconds 180 \
    --wait-interval-seconds 10 \
    --query "data.id" \
    --raw-output \
    2>&1
)"
STATUS=$?
set -e

echo "$OUTPUT"

if [[ $STATUS -eq 0 ]]; then
  INSTANCE_ID="$(printf '%s\n' "$OUTPUT" | tail -n 1 | tr -d '\r')"
  if [[ -z "$INSTANCE_ID" || "$INSTANCE_ID" == "null" ]]; then
    INSTANCE_ID="$(
      oci compute instance list \
        --compartment-id "$OCI_COMPARTMENT_OCID" \
        --display-name "$INSTANCE_NAME" \
        --all \
        --query "data[?\"lifecycle-state\"!='TERMINATED'] | [0].id" \
        --raw-output
    )"
  fi

  echo "SUCCESS: Oracle A1 instance created: $INSTANCE_ID"
  {
    echo "created=true"
    echo "exists=false"
    echo "instance_id=$INSTANCE_ID"
  } >> "$GITHUB_OUTPUT"
  exit 0
fi

if grep -Eqi \
  "Out of capacity|OutOfHostCapacity|out of host capacity|capacity.*not available|insufficient capacity" \
  <<<"$OUTPUT"; then
  echo "No A1 capacity right now. The next scheduled run will try again."
  {
    echo "created=false"
    echo "exists=false"
    echo "instance_id="
  } >> "$GITHUB_OUTPUT"
  exit 0
fi

echo "::error::OCI returned an unexpected error. This is not being treated as a normal capacity miss."
{
  echo "created=false"
  echo "exists=false"
  echo "instance_id="
} >> "$GITHUB_OUTPUT"
exit 1
