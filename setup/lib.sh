# Helper functions for the domain verify.sh scripts
PASS=0; FAIL=0

check() {
  local desc="$1"; shift
  if "$@" >/dev/null 2>&1; then
    echo "  ✅ $desc"; PASS=$((PASS+1))
  else
    echo "  ❌ $desc"; FAIL=$((FAIL+1))
  fi
}

# compare a jsonpath value: eq "<description>" "<expected>" kubectl get ... -o jsonpath=...
eq() {
  local desc="$1" expected="$2"; shift 2
  local actual; actual="$("$@" 2>/dev/null || true)"
  if [[ "$actual" == "$expected" ]]; then
    echo "  ✅ $desc"; PASS=$((PASS+1))
  else
    echo "  ❌ $desc (expected: '$expected', got: '$actual')"; FAIL=$((FAIL+1))
  fi
}

section() { echo; echo "── $1"; }

summary() {
  echo
  echo "Result: $PASS passed, $FAIL failed"
  [[ $FAIL -eq 0 ]]
}
