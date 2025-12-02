#!/usr/bin/env bash
set -euo pipefail

# Defaults allow overriding via Vagrant env configuration.
SSH_USER="${SSH_USER:-student}"
SSH_SHELL="${SSH_SHELL:-/bin/bash}"
SSH_BANNER_PATH="${SSH_BANNER_PATH:-/etc/ssh/sshd-banner}"
SSH_BANNER_MESSAGE="${SSH_BANNER_MESSAGE:-Authorized access only. Activity may be monitored.}"

if ! id "${SSH_USER}" >/dev/null 2>&1; then
  useradd -m -s "${SSH_SHELL}" "${SSH_USER}"
fi

install -o root -g root -m 0644 /dev/null "${SSH_BANNER_PATH}"
printf '%s\n' "${SSH_BANNER_MESSAGE}" > "${SSH_BANNER_PATH}"

if grep -Eq '^\s*Banner\s+' /etc/ssh/sshd_config; then
  sed -i "s|^\s*Banner\s\+.*$|Banner ${SSH_BANNER_PATH}|" /etc/ssh/sshd_config
else
  printf '\nBanner %s\n' "${SSH_BANNER_PATH}" >> /etc/ssh/sshd_config
fi

if systemctl list-unit-files | grep -q '^ssh\.service'; then
  systemctl restart ssh
else
  systemctl restart sshd || true
fi
