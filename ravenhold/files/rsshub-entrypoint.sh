#!/bin/sh
# Starts RSSHub with the X auth_token that analytics wrote to a shared file, and exits when that file
# changes so the restart policy (compose `restart: unless-stopped`, kubelet `restartPolicy: Always`)
# brings RSSHub back with the new token. RSSHub reads TWITTER_AUTH_TOKEN only from the environment at
# start, which is why a change needs a restart.
#
# The token is never echoed, never put in argv and shell tracing is never switched on: nothing here prints it.
#
# Environment:
#   RSSHUB_TOKEN_FILE           the file analytics writes (default /run/rsshub/x_auth_token)
#   RSSHUB_TOKEN_POLL_SECONDS   seconds between checks of the file (default 30; tests use a fraction)
# Arguments: when given, they replace RSSHub's start command (the hermetic test passes a fake one).
#
# RSSHub's start command, from the diygod/rsshub image's Dockerfile
# (https://github.com/DIYgod/RSSHub/blob/master/Dockerfile, lines 176-179, read 2026-11-23):
#   WORKDIR /app
#   ENTRYPOINT ["dumb-init", "--"]
#   CMD ["npm", "run", "start"]
# Running this script as the container entrypoint replaces both lines, so the default below is their
# concatenation: dumb-init -- npm run start.
set -eu

token_file="${RSSHUB_TOKEN_FILE:-/run/rsshub/x_auth_token}"
poll="${RSSHUB_TOKEN_POLL_SECONDS:-30}"

if [ "$#" -eq 0 ]; then
  set -- dumb-init -- npm run start
fi

# Checksum of the file's bytes; a missing file and an empty one both give the empty-input checksum.
file_sum() {
  cat "$token_file" 2>/dev/null | cksum
}

# Taken before the read, so a change in between is caught by the first poll instead of missed.
started_sum=$(file_sum)

if [ -s "$token_file" ]; then
  token_name=TWITTER_AUTH_TOKEN
  token_value=$(cat "$token_file")
  export "$token_name=$token_value"
  unset token_value
fi

"$@" &
child=$!

stop_child() {
  kill -TERM "$child" 2>/dev/null || true
  wait "$child" 2>/dev/null || true
}
trap 'stop_child; exit 143' TERM INT

while kill -0 "$child" 2>/dev/null; do
  sleep "$poll"
  if [ "$(file_sum)" != "$started_sum" ]; then
    echo "RSSHub token file changed; restarting RSSHub to pick it up." >&2
    stop_child
    exit 75
  fi
done

# RSSHub stopped on its own: report its exit code.
status=0
wait "$child" || status=$?
exit "$status"
