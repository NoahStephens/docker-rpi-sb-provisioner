#!/usr/bin/env bash
set -Eeuo pipefail

[ -f versions.json ]

cd "$(dirname "$(readlink -f "$BASH_SOURCE")")"

if [ "$#" -eq 0 ]; then
	versions="$(jq -r 'keys | map(@sh) | join(" ")' versions.json)"
	eval "set -- $versions"
fi

generated_warning() {
	cat <<'EOH'
#
# NOTE: THIS DOCKERFILE IS GENERATED VIA "apply-templates.sh"
#
# PLEASE DO NOT EDIT IT DIRECTLY.
#

EOH
}

escape_sed() {
	printf '%s' "$1" | sed -e 's/[\/&]/\\&/g'
}

for version; do
	export version
	fullVersion="$(jq -r '.[env.version].version' versions.json)"
	gitRef="$(jq -r '.[env.version].gitRef' versions.json)"
	gitCommit="$(jq -r '.[env.version].gitCommit' versions.json)"

	variants="$(jq -r '.[env.version].variants | keys | map(@sh) | join(" ")' versions.json)"
	eval "variants=( $variants )"

	rm -rf "$version"

	for variant in "${variants[@]}"; do
		export variant
		baseImage="$(jq -r '.[env.version].variants[env.variant].baseImage' versions.json)"

		dir="$version/$variant"
		mkdir -p "$dir"
		echo "processing $dir"

		{
			generated_warning
			sed \
				-e "s|%%BASE_IMAGE%%|$(escape_sed "$baseImage")|g" \
				-e "s|%%FULL_VERSION%%|$(escape_sed "$fullVersion")|g" \
				-e "s|%%GIT_REF%%|$(escape_sed "$gitRef")|g" \
				-e "s|%%GIT_COMMIT%%|$(escape_sed "$gitCommit")|g" \
				Dockerfile.template
		} > "$dir/Dockerfile"

		cp docker-entrypoint.sh "$dir/"
	done
done
