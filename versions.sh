#!/usr/bin/env bash
set -Eeuo pipefail

cd "$(dirname "$(readlink -f "$BASH_SOURCE")")"

upstreamRepo="${UPSTREAM_REPO:-https://github.com/raspberrypi/rpi-sb-provisioner.git}"
defaultVariant='bookworm'
defaultBaseImage='debian:bookworm-slim'
defaultPlatforms='["linux/amd64","linux/arm64"]'

tagRows=()
while IFS= read -r line; do
	tagRows+=( "$line" )
done < <(
	git ls-remote --tags "$upstreamRepo" \
		| awk '
			/refs\/tags\/v[0-9]+\.[0-9]+\.[0-9]+\^\{\}$/ {
				tag = $2
				sub(/^refs\/tags\//, "", tag)
				sub(/\^\{\}$/, "", tag)
				print tag " " $1
				next
			}
			/refs\/tags\/v[0-9]+\.[0-9]+\.[0-9]+$/ {
				tag = $2
				sub(/^refs\/tags\//, "", tag)
				print tag " " $1
			}
		' \
		| awk '!seen[$1]++' \
		| sort -k1,1V
)

if [ "${#tagRows[@]}" -eq 0 ]; then
	echo >&2 "error: no semver tags found in $upstreamRepo"
	exit 1
fi

find_tag_for_input() {
	local input="$1"
	if [[ "$input" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
		printf 'v%s\n' "$input"
		return 0
	fi
	if [[ "$input" =~ ^[0-9]+\.[0-9]+$ ]]; then
		local row latestTag=''
		for row in "${tagRows[@]}"; do
			tag="${row%% *}"
			case "$tag" in
				"v${input}."*)
					latestTag="$tag"
					;;
			esac
		done
		if [ -z "$latestTag" ]; then
			return 1
		fi
		printf '%s\n' "$latestTag"
		return 0
	fi
	echo >&2 "error: unsupported version selector '$input' (use X.Y or X.Y.Z)"
	return 1
}

if [ "$#" -eq 0 ]; then
	latestTagRow="${tagRows[${#tagRows[@]}-1]}"
	latestTag="${latestTagRow%% *}"
	set -- "${latestTag#v}"
	json='{}'
else
	json='{}'
	if [ -f versions.json ]; then
		json="$(< versions.json)"
	fi
fi

for requestedVersion; do
	resolvedTag="$(find_tag_for_input "$requestedVersion")"
	if [ -z "$resolvedTag" ]; then
		echo >&2 "error: could not resolve '$requestedVersion' in $upstreamRepo tags"
		exit 1
	fi

	fullVersion="${resolvedTag#v}"
	versionSeries="$(cut -d. -f1-2 <<<"$fullVersion")"
	gitCommit=''
	for row in "${tagRows[@]}"; do
		tag="${row%% *}"
		commit="${row##* }"
		if [ "$tag" = "$resolvedTag" ]; then
			gitCommit="$commit"
		fi
	done

	if [ -z "$gitCommit" ]; then
		echo >&2 "error: missing commit for $resolvedTag"
		exit 1
	fi

	echo "resolved $requestedVersion -> $fullVersion ($gitCommit)"

	export versionSeries fullVersion resolvedTag gitCommit defaultVariant defaultBaseImage defaultPlatforms
	json="$(
		jq -c --argjson current "$json" '
			$current
			| .[env.versionSeries] = {
				version: env.fullVersion,
				gitRef: env.resolvedTag,
				gitCommit: env.gitCommit,
				defaultVariant: env.defaultVariant,
				variants: {
					(env.defaultVariant): {
						baseImage: env.defaultBaseImage,
						platforms: (env.defaultPlatforms | fromjson)
					}
				}
			}
		' <<<"{}"
	)"
done

jq '
	to_entries
	| sort_by(.key | split(".") | map(tonumber))
	| reverse
	| from_entries
' <<<"$json" > versions.json
