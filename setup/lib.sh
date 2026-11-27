# Helper functions for the domain verify.sh scripts
#
# Usage of a verify.sh script:
#   ./verify.sh              check all tasks
#   ./verify.sh 1.9 1.12     check only these tasks
#   ./verify.sh --list       list the task sections
PASS=0; FAIL=0
FILTERS=(); LIST_ONLY=0; ACTIVE=1; MATCHED=0; SECTIONS=()
for arg in "$@"; do
  case "$arg" in
    -l|--list) LIST_ONLY=1 ;;
    -h|--help) echo "Usage: $0 [--list] [task ...]   e.g. $0 1.9 1.12"; exit 0 ;;
    *) FILTERS+=("$arg") ;;
  esac
done

# true if the current section is selected (use it to guard custom logic with side effects)
active() { [[ $ACTIVE -eq 1 ]]; }

check() {
  active || return 0
  local desc="$1"; shift
  if "$@" >/dev/null 2>&1; then
    echo "  ✅ $desc"; PASS=$((PASS+1))
  else
    echo "  ❌ $desc"; FAIL=$((FAIL+1))
  fi
}

# compare a jsonpath value: eq "<description>" "<expected>" kubectl get ... -o jsonpath=...
eq() {
  active || return 0
  local desc="$1" expected="$2"; shift 2
  local actual; actual="$("$@" 2>/dev/null || true)"
  if [[ "$actual" == "$expected" ]]; then
    echo "  ✅ $desc"; PASS=$((PASS+1))
  else
    echo "  ❌ $desc (expected: '$expected', got: '$actual')"; FAIL=$((FAIL+1))
  fi
}

# record a result from custom logic: pass "<description>" / fail "<description>"
pass() { echo "  ✅ $1"; PASS=$((PASS+1)); }
fail() { echo "  ❌ $1"; FAIL=$((FAIL+1)); }

# section "1.9 Dedicated node pool"  or  section "2.4 / 2.5 Flux"
section() {
  SECTIONS+=("$1")
  if [[ $LIST_ONLY -eq 1 ]]; then ACTIVE=0; return; fi
  ACTIVE=1
  if [[ ${#FILTERS[@]} -gt 0 ]]; then
    ACTIVE=0
    local id f
    for id in $(grep -oE '^[0-9]+\.[0-9]+( / [0-9]+\.[0-9]+)*' <<<"$1" | tr -d '/'); do
      for f in "${FILTERS[@]}"; do [[ "$id" == "$f" ]] && ACTIVE=1; done
    done
  fi
  if active; then MATCHED=$((MATCHED+1)); echo; echo "── $1"; fi
}

summary() {
  if [[ $LIST_ONLY -eq 1 ]]; then
    printf '%s\n' "${SECTIONS[@]}"; exit 0
  fi
  if [[ ${#FILTERS[@]} -gt 0 && $MATCHED -eq 0 ]]; then
    echo "No section matches: ${FILTERS[*]}. Available:"; printf '  %s\n' "${SECTIONS[@]}"; exit 2
  fi
  echo
  echo "Result: $PASS passed, $FAIL failed"
  [[ $FAIL -eq 0 ]]
}
