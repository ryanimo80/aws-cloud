#!/bin/bash
# Stop existing process
# test build
pkill node || true

cd /home/ec2-user/node-app
nohup npm start > app.log 2>&1 &
