#!/bin/zsh
# Creates guru-prasath-j/shelfsync (if missing) and pushes this repo.
set -e
cd "$(dirname "$0")"
set -a; . "$HOME/personal/.secrets/github.env"; set +a
code=$(curl -s -o /dev/null -w '%{http_code}' -X POST \
  -H "Authorization: Bearer $GITHUB_TOKEN" \
  -H "Accept: application/vnd.github+json" \
  https://api.github.com/user/repos \
  -d '{"name":"shelfsync","description":"CMS-driven, offline-first retail app in Flutter: server-driven UI, ETag caching, offline cart sync","private":false}')
case $code in
  201) echo "Repo created." ;;
  422) echo "Repo already exists, pushing to it." ;;
  *) echo "GitHub API returned $code (401 means the token expired)."; exit 1 ;;
esac
git remote remove origin 2>/dev/null || true
git remote add origin git@github.com:guru-prasath-j/shelfsync.git
git push -u origin main
echo "Done: https://github.com/guru-prasath-j/shelfsync"
