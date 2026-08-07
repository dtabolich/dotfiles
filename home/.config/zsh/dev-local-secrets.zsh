# Load secrets from the Dev-local vault via a vault-scoped service account.
# Personal / Work vaults are NOT visible to this token.
# Token file: ~/.config/op/service-account-dev-local.token (chmod 600)
# No credentials belong in this repo.

_DEV_LOCAL_OP_TOKEN_FILE="${HOME}/.config/op/service-account-dev-local.token"

_dev_local_op_read() {
  local ref="$1"
  [[ -r "$_DEV_LOCAL_OP_TOKEN_FILE" ]] || return 1
  command -v op >/dev/null || return 1
  OP_SERVICE_ACCOUNT_TOKEN="$(<"$_DEV_LOCAL_OP_TOKEN_FILE")" op read "$ref" 2>/dev/null
}

if [[ -z "${CONTEXT7_API_KEY:-}" ]]; then
  _v="$(_dev_local_op_read 'op://Dev-local/Cursor-Context7/credential')" && export CONTEXT7_API_KEY="$_v"
  unset _v
fi

if [[ -z "${AZURE_DEVOPS_EXT_PAT:-}" ]]; then
  _v="$(_dev_local_op_read 'op://Dev-local/Azure-DevOps-PAT/credential')" && export AZURE_DEVOPS_EXT_PAT="$_v"
  unset _v
fi
