#!/bin/bash
set -eo pipefail

# Find GitHub CLI binary
GH_BIN=""
if command -v mise >/dev/null 2>&1; then
  GH_BIN="$(mise which gh 2>/dev/null || true)"
fi
if [[ -z "$GH_BIN" || ! -x "$GH_BIN" ]]; then
  GH_BIN="$(command -v gh 2>/dev/null || true)"
fi
if [[ -z "$GH_BIN" || ! -x "$GH_BIN" ]]; then
  for candidate in "$HOME/.local/bin/gh" "$HOME/.local/share/mise/installs/gh/latest/gh_*/bin/gh" "/usr/bin/gh" "/usr/local/bin/gh"; do
    matched=($candidate)
    if [[ -x "${matched[0]}" ]]; then
      GH_BIN="${matched[0]}"
      break
    fi
  done
fi

if [[ -z "$GH_BIN" || ! -x "$GH_BIN" ]]; then
  echo '{"authenticated":false,"error":"GitHub CLI (gh) not found in PATH"}'
  exit 0
fi

# Check if authenticated
if ! "$GH_BIN" auth status >/dev/null 2>&1; then
  echo '{"authenticated":false,"error":"Not logged in. Run `gh auth login` in terminal."}'
  exit 0
fi

GQL_QUERY='
query {
  viewer {
    login
    name
    avatarUrl
    url
    pullRequests(first: 15, states: OPEN, orderBy: {field: UPDATED_AT, direction: DESC}) {
      totalCount
      nodes {
        number
        title
        url
        updatedAt
        isDraft
        repository {
          nameWithOwner
        }
        reviewDecision
        commits(last: 1) {
          nodes {
            commit {
              statusCheckRollup {
                state
              }
            }
          }
        }
      }
    }
  }
  search(query: "type:pr state:open review-requested:@me", type: ISSUE, first: 15) {
    issueCount
    nodes {
      ... on PullRequest {
        number
        title
        url
        updatedAt
        repository {
          nameWithOwner
        }
        author {
          login
          avatarUrl
        }
      }
    }
  }
}
'

GQL_OUT=$("$GH_BIN" api graphql -f query="$GQL_QUERY" 2>/dev/null || echo "{}")
NOTIF_OUT=$("$GH_BIN" api notifications 2>/dev/null || echo "[]")

jq -n \
  --argjson gql "$GQL_OUT" \
  --argjson notifs "$NOTIF_OUT" \
  '
  def time_ago(iso_str):
    if iso_str == null or iso_str == "" then ""
    else
      try (
        (iso_str | fromdateiso8601) as $t
        | (now - $t) as $diff
        | if $diff < 60 then "just now"
          elif $diff < 3600 then "\($diff / 60 | floor)m ago"
          elif $diff < 86400 then "\($diff / 3600 | floor)h ago"
          elif $diff < 604800 then "\($diff / 86400 | floor)d ago"
          else "\($diff / 604800 | floor)w ago"
          end
      ) catch ""
    end;

  def web_url(api_url):
    if api_url == null then ""
    else
      api_url
      | gsub("^https://api\\.github\\.com/repos/"; "https://github.com/")
      | gsub("/pulls/"; "/pull/")
      | gsub("/releases/[0-9]+$"; "/releases")
    end;

  def format_ci(ci):
    if ci == "SUCCESS" then "success"
    elif ci == "FAILURE" or ci == "ERROR" then "failure"
    elif ci == "PENDING" or ci == "EXPECTED" then "pending"
    else "none"
    end;

  def format_review(r):
    if r == "APPROVED" then "approved"
    elif r == "CHANGES_REQUESTED" then "changes_requested"
    elif r == "REVIEW_REQUIRED" then "review_required"
    else "none"
    end;

  ($gql.data.viewer // {}) as $v
  | ($v.pullRequests.nodes // []) as $prs
  | ($gql.data.search.nodes // []) as $reviews
  | ($notifs // []) as $n
  | {
      authenticated: ($v.login != null),
      user: {
        login: ($v.login // ""),
        name: ($v.name // $v.login // ""),
        avatarUrl: ($v.avatarUrl // ""),
        url: ($v.url // ("https://github.com/" + ($v.login // "")))
      },
      counts: {
        notifications: ($n | length),
        reviewRequests: ($reviews | length),
        myPrs: ($prs | length),
        failingCi: ([$prs[] | select(.commits.nodes[0].commit.statusCheckRollup.state == "FAILURE" or .commits.nodes[0].commit.statusCheckRollup.state == "ERROR")] | length),
        runningCi: ([$prs[] | select(.commits.nodes[0].commit.statusCheckRollup.state == "PENDING" or .commits.nodes[0].commit.statusCheckRollup.state == "EXPECTED")] | length),
        passingCi: ([$prs[] | select(.commits.nodes[0].commit.statusCheckRollup.state == "SUCCESS")] | length)
      },
      notifications: [
        $n[] | {
          id: .id,
          reason: .reason,
          title: .subject.title,
          type: .subject.type,
          repo: .repository.full_name,
          updatedAt: .updated_at,
          timeAgo: time_ago(.updated_at),
          url: (web_url(.subject.url) | if . == "" then .repository.html_url else . end)
        }
      ],
      reviewRequests: [
        $reviews[] | {
          number: .number,
          title: .title,
          repo: .repository.nameWithOwner,
          author: .author.login,
          avatarUrl: .author.avatarUrl,
          updatedAt: .updatedAt,
          timeAgo: time_ago(.updatedAt),
          url: .url
        }
      ],
      myPrs: [
        $prs[] | {
          number: .number,
          title: .title,
          repo: .repository.nameWithOwner,
          isDraft: .isDraft,
          reviewDecision: format_review(.reviewDecision),
          ciState: format_ci(.commits.nodes[0].commit.statusCheckRollup.state),
          updatedAt: .updatedAt,
          timeAgo: time_ago(.updatedAt),
          url: .url
        }
      ],
      timestamp: (now | floor)
    }
  '
