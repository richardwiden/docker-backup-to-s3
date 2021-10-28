#!/bin/bash
docker volume create data
docker run  --rm  --name backup --network local  -v data:/data    \
-e AWS_DEFAULT_REGION -e AWS_ACCESS_KEY_ID -e AWS_SECRET_ACCESS_KEY \
-e S3_PATH -e S3_ENDPOINT -e AES_PASSPHRASE -e VERSION \
docker-backup-to-s3:latest restore
docker kill s3
docker run -d  --name helper -v data:/data busybox true
docker cp helper:/data test_output
docker rm helper
docker volume rm data
diff test_input test_output/test_input