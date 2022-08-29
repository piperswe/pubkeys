#!/usr/bin/env bash

set -euxo pipefail

wget https://github.com/piperswe.keys -O ssh_public_keys
wget https://github.com/piperswe.gpg -O pgp_public_keys