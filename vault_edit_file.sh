#!/usr/bin/env bash

# Plaintext vault decryption key, not checked into SCM
VAULTFILE="${VAULTFILE:-$HOME/.ssh/creds/ansible_vault.txt}"



command="$1"; shift
file="$1"

if [[ $command == '' ]]; then
  echo "ERROR: You must enter a file name."
  echo "Example:"
  echo "  ${0} create inventory/group_name/_vault_keyname.yml"
  echo "  ${0} edit   inventory/group_name/_vault_keyname.yml"
  echo "  ${0} view   inventory/group_name/_vault_keyname.yml"
  echo
  exit 1
fi


VAULTOPTS="--vault-password-file=$VAULTFILE"

pipenv run ansible-vault $command "${file}" $VAULTOPTS
