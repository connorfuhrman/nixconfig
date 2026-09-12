#!/usr/bin/env bash
# Validate .cursor/environment.json against Cursor's public schema.
set -euo pipefail

ENV_FILE=".cursor/environment.json"
SCHEMA_URL="https://cursor.com/schemas/environment.schema.json"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "cursor-env-schema: missing ${ENV_FILE}" >&2
  exit 1
fi

if ! python3 -m json.tool "$ENV_FILE" >/dev/null 2>&1; then
  echo "cursor-env-schema: ${ENV_FILE} is not valid JSON" >&2
  exit 1
fi

schema_file="$(mktemp)"
trap 'rm -f "$schema_file"' EXIT

if ! curl -fsSL "$SCHEMA_URL" -o "$schema_file"; then
  echo "cursor-env-schema: failed to fetch schema from ${SCHEMA_URL}" >&2
  exit 1
fi

python3 -m pip install --quiet --disable-pip-version-check check-jsonschema
python3 -m check_jsonschema --schemafile "$schema_file" "$ENV_FILE"

echo "cursor-env-schema: ${ENV_FILE} validates against Cursor environment schema"
