#!/usr/bin/env bash
set -eu

## Setting up tools
gcloud="$1"

## ---
export AWS_ACCESS_KEY_ID="${AWS_EXECUTOR_AMI_ACCESS_KEY}"
export AWS_SECRET_ACCESS_KEY="${AWS_EXECUTOR_AMI_SECRET_KEY}"

# Point to GCP boot disk image/AMI built by build.sh script
NAME="${IMAGE_FAMILY}"
if [ "${RELEASE_INTERNAL:-}" == "true" ]; then
  NAME="${NAME}-${BUILDKITE_BUILD_NUMBER}"
fi
GOOGLE_IMAGE_NAME="${NAME}"

# Mark GCP boot disk as released and make it usable outside of Sourcegraph.
"$gcloud" compute images add-iam-policy-binding --project=sourcegraph-ci "${GOOGLE_IMAGE_NAME}" --member='allAuthenticatedUsers' --role='roles/compute.imageUser'
"$gcloud" compute images update --project=sourcegraph-ci "${GOOGLE_IMAGE_NAME}" --family="${IMAGE_FAMILY}"

if [ "${EXECUTOR_IS_TAGGED_RELEASE}" = "true" ]; then
  REGIONS=$(jq -r '.[]' <cmd/executor/docker-mirror/aws_regions.json)
  for region in $REGIONS; do
    AWS_AMI_ID=$(aws ec2 --region="${region}" describe-images --filter "Name=name,Values=${NAME}" --query 'Images[*].[ImageId]' --output text)
    # Make AMI usable outside of Sourcegraph.
    aws ec2 --region="${region}" modify-image-attribute --image-id "${AWS_AMI_ID}" --launch-permission "Add=[{Group=all}]"
  done
else
  AWS_AMI_ID=$(aws ec2 --region="us-west-2" describe-images --filter "Name=name,Values=${NAME}" --query 'Images[*].[ImageId]' --output text)
  # Make AMI usable outside of Sourcegraph.
  aws ec2 --region="us-west-2" modify-image-attribute --image-id "${AWS_AMI_ID}" --launch-permission "Add=[{Group=all}]"
fi
