#!/usr/bin/env bash
set -Eeuo pipefail

cd "$(dirname "$(readlink -f "$BASH_SOURCE")")"

if [ "$#" -eq 0 ]; then
	versions="$(jq -r 'keys | map(@sh) | join(" ")' versions.json)"
	eval "set -- $versions"
fi

IFS=$'\n'; set -- $(sort -rV <<<"$*"); unset IFS

fileCommit() {
	git log -1 --format='format:%H' HEAD -- "$@" 2>/dev/null || true
}

dirCommit() {
	local dir="$1"
	local c
	c="$(fileCommit "$dir/Dockerfile" "$dir/docker-entrypoint.sh")"
	if [ -z "$c" ]; then
		c="$(git rev-parse HEAD 2>/dev/null || true)"
	fi
	printf '%s\n' "$c"
}

join() {
	local sep="$1"
	shift
	local out
	printf -v out "${sep//%/%%}%s" "$@"
	echo "${out#$sep}"
}

selfCommit="$(fileCommit "$0")"
if [ -z "$selfCommit" ]; then
	selfCommit="$(git rev-parse HEAD 2>/dev/null || true)"
fi

cat <<-EOH
# this file is generated via https://github.com/noahstephens/docker-rpi-sb-provisioner/blob/$selfCommit/generate-stackbrew-library.sh

Maintainers: Noah Stephens <opensource@noahstephens.com> (@noahstephens)
GitRepo: https://github.com/noahstephens/docker-rpi-sb-provisioner.git
EOH

for version; do
	export version
	fullVersion="$(jq -r '.[env.version].version' versions.json)"
	defaultVariant="$(jq -r '.[env.version].defaultVariant' versions.json)"
	major="${version%%.*}"

	variants="$(jq -r '.[env.version].variants | keys | map(@sh) | join(" ")' versions.json)"
	eval "variants=( $variants )"

	baseAliases=(
		"$fullVersion"
		"$version"
		"$major"
	)

	for variant in "${variants[@]}"; do
		export variant
		dir="$version/$variant"
		commit="$(dirCommit "$dir")"
		platforms="$(jq -r '.[env.version].variants[env.variant].platforms | join(" ")' versions.json)"

		variantAliases=(
			"${fullVersion}-${variant}"
			"${version}-${variant}"
			"${major}-${variant}"
		)

		if [ "$variant" = "$defaultVariant" ]; then
			variantAliases=( "${baseAliases[@]}" "${variantAliases[@]}" )
		fi

		cleanAliases=()
		for tag in "${variantAliases[@]}"; do
			[ -n "$tag" ] || continue
			cleanAliases+=( "$tag" )
		done

		echo
		cat <<-EOE
			Tags: $(join ', ' "${cleanAliases[@]}")
			Architectures: $(join ', ' $platforms)
			GitCommit: $commit
			Directory: $dir
		EOE
	done
done
