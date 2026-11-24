#!/usr/bin/env bash
set -euo pipefail

title='Acceptance_fixture'
artifacts="$RUNNER_TEMP/wiki-evidence"
mediawiki_image='mediawiki@sha256:9692cc01b83b4b0f9d775b0ac16ec681578f6c47fb5e67c59e6a9c204442b9f7'
tunnel_image='cloudflare/cloudflared@sha256:55c7e3e8d89d5e8d20b75a82f3602cbf98e06db406e73e282073cfdc5a9a3af6'

edit() {
  docker exec -i cw-public-wiki php maintenance/run.php edit --user Admin --summary "$1" "$title"
}

query() {
  local -a params=(action=query prop=revisions format=json formatversion=2 "titles=$title" rvlimit=1 'rvprop=ids|timestamp')
  local -a options=()
  for parameter in "${params[@]}"; do
    options+=(--data-urlencode "$parameter")
  done
  curl --fail --silent --show-error --noproxy '*' --max-time 12 --get http://127.0.0.1:8833/api.php "${options[@]}"
}

prepare() {
  mkdir -p "$artifacts"
  docker run -d --name cw-public-wiki -p 127.0.0.1:8833:80 "$mediawiki_image"
  docker exec cw-public-wiki mkdir -p /var/www/data
  docker exec cw-public-wiki chown www-data:www-data /var/www/data
  local -a install=(--dbtype sqlite --dbpath /var/www/data --dbname acceptance --scriptpath= --server=http://127.0.0.1:8833)
  openssl rand -hex 24 | docker exec -i cw-public-wiki php maintenance/run.php install "${install[@]}" --passfile /dev/stdin 'Credential Watch acceptance' Admin
  docker exec cw-public-wiki chown -R www-data:www-data /var/www/data
  echo 'Clean baseline for a synthetic detection exercise.' | edit baseline
  query > "$artifacts/baseline.json"
  page_id="$(python -c 'import json,sys; print(json.load(sys.stdin)["query"]["pages"][0]["pageid"])' < "$artifacts/baseline.json")"
  python -u wiki-readonly.py "$page_id" > "$artifacts/gateway.log" 2>&1 &
  docker run -d --network host --name cw-public-wiki-tunnel "$tunnel_image" tunnel --no-autoupdate --url http://127.0.0.1:8834
  for attempt in $(seq 1 30); do
    hostname="$(docker logs cw-public-wiki-tunnel 2>&1 | grep -oE '[a-z0-9-]+\.trycloudflare\.com' | head -1 || true)"
    if [[ -n "$hostname" ]]; then
      reply="$(curl --silent --show-error --fail --max-time 6 "https://$hostname/api.php?action=query&prop=revisions&format=json&formatversion=2&pageids=$page_id&rvlimit=100&rvprop=ids%7Ctimestamp" || true)"
      if [[ "$reply" == *'"revid"'* ]]; then
        printf 'hostname=%s\npage_id=%s\n' "$hostname" "$page_id" >> "$GITHUB_OUTPUT"
        printf '{"host":"%s","page_id":%s}\n' "$hostname" "$page_id" > "$artifacts/endpoint.json"
        return
      fi
    fi
    sleep 2
  done
  echo 'Read-only public endpoint did not become available.' >&2
  exit 1
}

publish() {
  sleep 150
  for num in $(seq -w 1 24); do
    sample="public-$num"
    edit "$sample" < "$sample.wiki"
    query > "$artifacts/$sample.json"
    if [[ "$num" == 07 ]]; then
      echo 'Clean revision after sample 07.' | edit 'Remove the synthetic sample'
      query > "$artifacts/cleanup-07.json"
    fi
    sleep 6
  done
  docker exec cw-public-wiki php maintenance/run.php dumpBackup --full --quiet > "$artifacts/revisions.xml"
}

case "${1:-}" in
  prepare) prepare ;;
  publish) publish ;;
  *) exit 2 ;;
esac
