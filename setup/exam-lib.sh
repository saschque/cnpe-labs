# Shared helpers for the mock exam verify.sh scripts.
# Usage in a script:
#   source "$(dirname "$0")/../../setup/exam-lib.sh"
#   t1() { ...; }   # one check function per task, exit code 0 = passed
#   run_exam "4:Quota" "5:HPA" ...   # order = task number, format "<points>:<name>"

k() { kubectl "$@" 2>/dev/null; }
jp() { k "$@"; }                  # shorthand for jsonpath queries
is() { [[ "$1" == "$2" ]]; }      # is <expected> "$(command)"

run_exam() {
  local score=0 max=0 i=0 pts name entry
  for entry in "$@"; do
    i=$((i + 1)); pts="${entry%%:*}"; name="${entry#*:}"
    max=$((max + pts))
    if "t$i" >/dev/null 2>&1; then
      score=$((score + pts)); printf "  ✅ %2d  %-45s +%d\n" "$i" "$name" "$pts"
    else
      printf "  ❌ %2d  %-45s  0/%d\n" "$i" "$name" "$pts"
    fi
  done
  local pct=$((score * 100 / max))
  echo
  echo "Result: $score / $max points ($pct %) – $([[ $pct -ge 66 ]] && echo 'PASSED 🎉' || echo 'not passed yet')"
}
