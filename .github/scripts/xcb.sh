#!/bin/bash
# Lance xcodebuild et, en cas d'échec, remonte les lignes d'erreur
# sous forme d'annotations GitHub (lisibles sans télécharger les journaux).
log="$RUNNER_TEMP/xcodebuild-$(date +%s).log"
xcodebuild "$@" > "$log" 2>&1
status=${PIPESTATUS[0]}
if [ "$status" -ne 0 ]; then
  grep -iE "error|failed|no profiles|no signing|not found|invalid|unauthorized|forbidden|requires a provisioning|provisioning profile|certificate|account" "$log" \
    | grep -vE "^\s*$" | awk '!seen[$0]++' | tail -n 25 \
    | while IFS= read -r line; do echo "::error::${line:0:900}"; done
  echo "::error::xcodebuild a échoué (code $status)"
fi
exit "$status"
