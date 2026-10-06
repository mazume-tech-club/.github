#!/usr/bin/env bash
# 組織の public リポジトリ全体の統計を集計し、shields.io endpoint 用 JSON を出力する
set -euo pipefail

ORG="${ORG:-mazume-tech-club}"
OUT="profile/stats"
mkdir -p "$OUT"

write_badge() { # name label message color
  jq -n --arg l "$2" --arg m "$3" --arg c "$4" \
    '{schemaVersion:1,label:$l,message:$m,color:$c}' > "$OUT/$1.json"
}

commits=0; adds=0; dels=0
repos=$(gh repo list "$ORG" --visibility public --source --limit 200 --json name -q '.[].name')

for r in $repos; do
  stats=""
  for _ in $(seq 1 10); do # 集計中は空レスポンス(202)が返るので再試行
    stats=$(gh api "repos/$ORG/$r/stats/contributors" 2>/dev/null || true)
    [ -n "$stats" ] && break
    sleep 6
  done
  [ -z "$stats" ] && continue
  read -r c a d < <(echo "$stats" | jq -r '[.[].weeks[]] | "\(map(.c)|add // 0) \(map(.a)|add // 0) \(map(.d)|add // 0)"')
  commits=$((commits + c)); adds=$((adds + a)); dels=$((dels + d))
done

issues_total=$(gh api -X GET search/issues -f q="org:$ORG is:issue is:public" -q .total_count)
issues_open=$(gh api -X GET search/issues -f q="org:$ORG is:issue is:public is:open" -q .total_count)
repo_count=$(echo "$repos" | grep -c . || true)

write_badge commits   "commits"   "$commits"                       F38020
write_badge additions "additions" "+$adds"                         2EA043
write_badge deletions "deletions" "-$dels"                         CF222E
write_badge issues    "issues"    "$issues_open open / $issues_total total" 6366F1
write_badge repos     "repos"     "$repo_count"                    0F172A
