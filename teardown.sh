#!/bin/bash
set -e

echo "======================================"
echo "  Weather App Infrastructure Teardown"
echo "======================================"
echo ""
echo "WARNING: This will delete all AWS resources for weather-app."
echo "This action is irreversible."
echo ""
read -p "Are you sure you want to proceed? (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
  echo "Teardown cancelled."
  exit 0
fi

AWS_REGION=$(aws configure get region)

delete_stack() {
  local stack_name=$1
  echo ""
  echo "Deleting stack: $stack_name..."

  if aws cloudformation describe-stacks --stack-name $stack_name --region $AWS_REGION &>/dev/null; then
    aws cloudformation delete-stack --stack-name $stack_name --region $AWS_REGION
    echo "Waiting for $stack_name to be deleted..."
    aws cloudformation wait stack-delete-complete --stack-name $stack_name --region $AWS_REGION
    echo "$stack_name deleted successfully."
  else
    echo "$stack_name does not exist, skipping."
  fi
}

AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
ARTIFACT_BUCKET="weather-app-artifacts-$AWS_ACCOUNT_ID"

echo ""
echo "Emptying S3 artifact bucket: $ARTIFACT_BUCKET..."
if aws s3api head-bucket --bucket $ARTIFACT_BUCKET 2>/dev/null; then
  aws s3 rm s3://$ARTIFACT_BUCKET --recursive
  echo "Bucket emptied successfully."
else
  echo "Bucket does not exist, skipping."
fi

echo ""
echo "Deleting all images from ECR repository: weather-app..."
if aws ecr describe-repositories --repository-names weather-app --region $AWS_REGION &>/dev/null; then
  IMAGE_IDS=$(aws ecr list-images --repository-name weather-app --region $AWS_REGION --query 'imageIds[*]' --output json)
  if [ "$IMAGE_IDS" != "[]" ]; then
    aws ecr batch-delete-image --repository-name weather-app --region $AWS_REGION --image-ids "$IMAGE_IDS"
    echo "ECR images deleted successfully."
  else
    echo "No images found in ECR, skipping."
  fi
else
  echo "ECR repository does not exist, skipping."
fi

# Delete in reverse order
delete_stack "weather-app-monitoring"
delete_stack "weather-app-ecr"
delete_stack "weather-app-compute"
delete_stack "weather-app-networking"
delete_stack "weather-app-iam"
delete_stack "weather-app-bootstrap"

echo ""
echo "======================================"
echo "  Teardown complete!"
echo "======================================"
echo ""
echo "Note: SSM parameter /weather-app/api-key was not deleted."
echo "Delete it manually from AWS Console → Parameter Store if needed."