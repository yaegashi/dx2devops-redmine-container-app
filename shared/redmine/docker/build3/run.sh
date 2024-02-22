#!/bin/bash

set -ex

cat <<EOF >config/sidekiq.yml
---
:queues:
  - mailers
EOF

cat <<EOF >config/additional_environment.rb
config.active_job.queue_adapter = :sidekiq
EOF
