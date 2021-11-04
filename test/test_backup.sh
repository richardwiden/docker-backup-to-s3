#!/bin/bash
echo ---Destroying crap---
docker kill s3 || true
docker kill backup || true
docker network rm local|| true
docker volume rm data || true

echo ---Building and starting up docker---
docker network create local

docker volume create data;
docker run  --name helper -v data:/data busybox
echo "my test data" > test_input
echo "file_that_should_be_excluded" > file_that_should_be_excluded
docker cp test_input helper:/data
docker cp file_that_should_be_excluded helper:/data
docker rm helper

docker build --tag docker-backup-to-s3:latest .
docker run --rm --network local --name s3 -d -p 9000:9000 -e USER="$AWS_ACCESS_KEY_ID" -e PASSWORD="$AWS_SECRET_ACCESS_KEY" altmannmarcelo/minio:latest
docker run --rm --network local --name aws -e AWS_ACCESS_KEY_ID -e AWS_SECRET_ACCESS_KEY -e AWS_EC2_METADATA_DISABLED=true amazon/aws-cli --endpoint-url http://s3:9000 s3 mb s3://my-bucket
docker run --rm --network local --name backup -v data:/data -e AWS_DEFAULT_REGION -e AWS_ACCESS_KEY_ID -e AWS_SECRET_ACCESS_KEY -e AWS_EC2_METADATA_DISABLED -e S3_PATH -e S3_ENDPOINT -e AES_PASSPHRASE -e EXCLUDE_FILES -e DELETE_OLDER_THAN docker-backup-to-s3:latest backup-once
sleep 10
VERSION=$(docker run --rm --network local --name backup -v data:/data -e AWS_DEFAULT_REGION -e AWS_ACCESS_KEY_ID -e AWS_SECRET_ACCESS_KEY -e AWS_EC2_METADATA_DISABLED -e S3_PATH -e S3_ENDPOINT -e AES_PASSPHRASE -e EXCLUDE_FILES -e DELETE_OLDER_THAN docker-backup-to-s3:latest backup-once)
export VERSION
echo "VERSION=$VERSION"
echo "VERSION=$VERSION"  >> $GITHUB_ENV
docker volume rm data