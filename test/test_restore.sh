#!/bin/bash

docker volume create data

docker run  --name backup --network local  -v data:/data    \
-e AWS_DEFAULT_REGION -e AWS_ACCESS_KEY_ID -e AWS_SECRET_ACCESS_KEY \
-e S3_PATH -e S3_ENDPOINT -e AES_PASSPHRASE -e VERSION \
docker-backup-to-s3:latest restore
docker logs backup
docker rm backup
docker kill s3
docker run -d  --name helper -v data:/data busybox true
docker cp helper:/data test_output
docker rm helper
docker volume rm data
if [ -f "test_output/test_input" ]; then
  diff test_input test_output/test_input
else
  echo "File missing from restore"
  exit 1
fi
if [ -f "test_output/file_that_should_be_excluded" ]; then
  echo "Excluded file was restored"
  exit 1
fi