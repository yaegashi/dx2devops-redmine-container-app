#!/bin/bash

set -ex

ln -sf /docker/rmops /usr/local/bin

ln -sf /docker/build3/config.ru .

cat <<EOF >config/sidekiq.yml
---
:queues:
  - mailers
EOF

cat <<EOF >config/additional_environment.rb
config.active_job.queue_adapter = :sidekiq
EOF
