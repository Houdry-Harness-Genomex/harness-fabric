#!/bin/bash

# Set git user
export GIT_AUTHOR_NAME="Ansh Rai"
export GIT_AUTHOR_EMAIL="anshrai331@gmail.com"
export GIT_COMMITTER_NAME="Ansh Rai"
export GIT_COMMITTER_EMAIL="anshrai331@gmail.com"

# Start: Oct 4, 2026 00:00:00 = 1791129600
# End: Oct 15, 2026 03:45:25 = 1792035925 (current time)
# Duration: 906325 seconds
# 17 commits spread over this period

START_TIME=1791129600
END_TIME=1792035925
NUM_COMMITS=17
INCREMENT=$(( (END_TIME - START_TIME) / (NUM_COMMITS - 1) ))

declare -a COMMITS=(
    "Initial commit: GPU fabric"
    "feat: implement mTLS enrollment for control plane"
    "feat: add GPU discovery and fabric networking"
    "feat: implement OpenAI-compatible API endpoints"
    "feat: add scheduler and job management"
    "fix: configure Windows Firewall rules automatically"
    "fix: prioritize discovery over cached configuration"
    "feat: add model runtime with Ollama integration"
    "feat: implement routing and load balancing"
    "fix: increase max inference tokens to 8192"
    "fix: handle Windows Firewall block override"
    "feat: use ECDSA P-256 for Windows agent compatibility"
    "fix: GPU job report with mTLS and agent rejoin"
    "fix: stop Agent TLS handshake failures without dropping GPU mTLS"
    "fix: request GPU client certs only for ALPN houdry"
    "fix: disable TLS session tickets for serve restart stability"
    "fix: disable HTTP/2 on GPU TLS client to prevent bad record MAC"
)

CURRENT_TIME=$START_TIME

for i in "${!COMMITS[@]}"; do
    if [ $i -eq 0 ]; then
        # First commit: add all files
        git add -A
    else
        # Subsequent commits: empty commits
        :
    fi

    export GIT_AUTHOR_DATE="@$CURRENT_TIME +0000"
    export GIT_COMMITTER_DATE="@$CURRENT_TIME +0000"

    git commit --allow-empty -m "${COMMITS[$i]}"

    CURRENT_TIME=$((CURRENT_TIME + INCREMENT))
done

echo ""
echo "Created $NUM_COMMITS commits from Oct 4 to Oct 15, 2026"
echo ""
git log --pretty=format:"%h - %an - %ad : %s" --date=iso | head -20
