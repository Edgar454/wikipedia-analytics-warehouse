#!/bin/bash
set -e

pushd infra/infra_docs
  terraform init -input=false
  terraform apply --auto-approve

  BUCKET_NAME=$(terraform output -raw s3_bucket_name)
  CLOUDFRONT_DISTRIBUTION_ID=$(terraform output -raw cloudfront_distribution_id)
  CLOUDFRONT_DISTRIBUTION_DOMAIN_NAME=$(terraform output -raw cloudfront_distribution_domain_name)
  CLOUDFRONT_DISTRIBUTION_URL=$(terraform output -raw cloudfront_distribution_url)
popd

pushd dbt
  dbt docs generate
  aws s3 sync target/ s3://$BUCKET_NAME/
  aws cloudfront create-invalidation --distribution-id $CLOUDFRONT_DISTRIBUTION_ID --paths "/*"
popd

echo "Documentation deployed to: $CLOUDFRONT_DISTRIBUTION_URL"