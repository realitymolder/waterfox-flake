#!/bin/sh

ci=false
if echo "$@" | grep -qoE '(--ci)'; then
    ci=true
fi

only_check=false
if echo "$@" | grep -qoE '(--only-check)'; then
    only_check=true
fi

# Get latest Waterfox release
curl -sL -H "Accept: application/vnd.github+json" -H "X-GitHub-Api-Version: 2022-11-28" \
    "https://api.github.com/repos/BrowserWorks/Waterfox/releases/latest" > /tmp/latest_release.json

# Check if curl succeeded
if [ ! -s /tmp/latest_release.json ]; then
    echo "Error: Failed to fetch latest release from GitHub API"
    exit 1
fi

latest_release=$(cat /tmp/latest_release.json)

get_latest_version() {
    version=$(echo "$latest_release" | jq -r '.tag_name // empty')
    echo "${version#v}"
}

get_latest_updated_at() {
    echo "$latest_release" | jq -r '.published_at'
}

current_version=$(get_latest_version)
current_updated_at=$(get_latest_updated_at)

commit_targets=""
commit_version=""

update_version() {
    # "x86_64" or "aarch64"
    arch=$1
    # "linux" or "darwin"
    os=$2

    meta=$(jq ".[\"main\"][\"$arch-$os\"]" <sources.json)
    local_version=$(echo "$meta" | jq -r '.version')

    echo "Checking main version @ $arch-$os... local=$local_version remote=$current_version"

    if [ "$local_version" = "$current_version" ]; then
        echo "Local main version is up to date"
        return
    fi

    echo "Local main version mismatch with remote"

    if $only_check; then
        echo "should_update=true" >>"$GITHUB_OUTPUT"
        exit 0
    fi

    if [ "$os" = "darwin" ]; then
        download_url="https://cdn.waterfox.com/waterfox/releases/$current_version/Darwin_x86_64-aarch64/Waterfox%20$current_version.dmg"
        prefetch_output=$(nix store prefetch-file --hash-type sha256 --json "$download_url")
    else
        download_url="https://cdn.waterfox.com/waterfox/releases/$current_version/Linux_x86_64/waterfox-$current_version.tar.bz2"
        prefetch_output=$(nix store prefetch-file --unpack --hash-type sha256 --json "$download_url")
    fi
    sha256=$(echo "$prefetch_output" | jq -r '.hash')

    jq ".[\"main\"][\"$arch-$os\"] = {\"version\":\"$current_version\",\"url\":\"$download_url\",\"sha256\":\"$sha256\"}" <sources.json >sources.json.tmp
    mv sources.json.tmp sources.json

    echo "main was updated to $current_version"

    if ! $ci; then
        return
    fi

    if [ "$commit_targets" = "" ]; then
        commit_targets="$arch-$os"
        commit_version="$current_version"
    elif ! echo "$commit_targets" | grep -q "$arch-$os"; then
        commit_targets="$commit_targets && $arch-$os"
    fi
}

main() {
    set -e

    update_version "x86_64" "linux"
    update_version "aarch64" "darwin"

    if $only_check && $ci; then
        echo "should_update=false" >>"$GITHUB_OUTPUT"
    fi

    # Check if there are changes
    if ! git diff --exit-code >/dev/null; then
        # Prepare commit message
        message="chore(update): waterfox @ $commit_targets to $commit_version"

        echo "commit_message=$message" >>"$GITHUB_OUTPUT"
        echo "should_rebase_beta=false" >>"$GITHUB_OUTPUT"
    fi
}

main
