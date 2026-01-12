#!/bin/bash

UTGARD_CONFIG_PATH="${UTGARD_CONFIG_PATH:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/provision/config.yml}"

utgard_config_get() {
  local key="$1"
  local fallback="$2"
  local value=""

  if command -v ruby >/dev/null 2>&1 && [ -f "$UTGARD_CONFIG_PATH" ]; then
    value="$(ruby -ryaml -e 'cfg=YAML.load_file(ARGV[0]); key=ARGV[1]; val=key.split(".").inject(cfg){|c,k| c.is_a?(Hash) ? c[k] : nil}; puts(val.nil? ? "" : val)' "$UTGARD_CONFIG_PATH" "$key")"
  fi

  if [ -z "$value" ]; then
    value="$fallback"
  fi

  echo "$value"
}
