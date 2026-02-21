#!/bin/bash
# ---- This script transfers data from phase2 to phase3
if [[ "${EUID}" -ne 0 ]]; then
  echo "Error: please run as root (example: sudo bash setup-docker.sh)"
  exit 1
fi

# ---- Dump data into phase3/dump folder
if [[ ! -d "./phase3/dump" ]]; then
    mkdir "./phase3/dump"
    echo "Created dump folder"
fi

mongodump mongodb://localhost:27017 --out ./phase3/dump  --db products_db

echo "finished file dump"

# ---- import data into mongodb container
if command -v docker >/dev/null 2>&1; then
    docker exec midterm_mongo mongorestore --dir /dump
    rm -rf ./dump
else
    echo "Please install docker"
fi

# ---- Copy uploads ----
cp -r ./phase1/public/uploads/* /var/lib/docker/volumes/phase3_uploads_data/_data/

echo "Data Transfer complete"