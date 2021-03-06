#!/bin/bash
set -e

cd "$(dirname "$(readlink -f "$BASH_SOURCE")")"

declare -A aliases
aliases=(
	[$(< latest)]='latest'
)
declare -A noVersion
noVersion=(
)

develSuite="$(wget -qO- http://archive.ubuntu.com/ubuntu/dists/devel/Release | awk -F ': ' '$1 == "Codename" { print $2; exit }' || true)"
if [ "$develSuite" ]; then
	aliases[$develSuite]+=' devel'
fi

versions=( */ )
versions=( "${versions[@]%/}" )

cat <<-EOH
# Maintained by Tianon as proxy for upstream's offical builds.

Maintainers: Tianon Gravi <tianon@debian.org> (@tianon)
GitRepo: https://github.com/tianon/docker-brew-ubuntu-core.git
GitFetch: refs/heads/dist

# see https://partner-images.canonical.com/core/
# see also https://wiki.ubuntu.com/Releases#Current
EOH

commitRange='master..dist'
commitCount="$(git rev-list "$commitRange" --count 2>/dev/null || true)"
if [ "$commitCount" ] && [ "$commitCount" -gt 0 ]; then
	echo
	echo '# commits:' "($commitRange)"
	git log --format=format:'- %h %s%n%w(0,2,2)%b' "$commitRange" | sed 's/^/#  /'
fi

# prints "$2$1$3$1...$N"
join() {
	local sep="$1"; shift
	local out; printf -v out "${sep//%/%%}%s" "$@"
	echo "${out#$sep}"
}

arch="$(dpkg --print-architecture)"
for version in "${versions[@]}"; do
	tarball="$version/ubuntu-$version-core-cloudimg-$arch-root.tar.gz"
	commit="$(git log -1 --format='format:%H' -- "$version")"

	serial="$(awk -F '=' '$1 == "SERIAL" { print $2; exit }' "$version/build-info.txt" 2>/dev/null || true)"
	[ "$serial" ] || continue

	versionAliases=()

	[ -s "$version/alias" ] && versionAliases+=( $(< "$version/alias") )

	if [ -z "${noVersion[$version]}" ]; then
		fullVersion="$(git show "$commit:$tarball" | tar -xvz etc/debian_version --to-stdout 2>/dev/null || true)"
		if [ -z "$fullVersion" ] || [[ "$fullVersion" == */sid ]]; then
			fullVersion="$(eval "$(git show "$commit:$tarball" | tar -xvz etc/os-release --to-stdout 2>/dev/null || true)" && echo "$VERSION" | cut -d' ' -f1)"
		fi
		if [ "$fullVersion" ]; then
			#versionAliases+=( $fullVersion )
			if [ "${fullVersion%.*.*}" != "$fullVersion" ]; then
				# three part version like "12.04.4"
				#versionAliases+=( ${fullVersion%.*} )
				versionAliases=( $fullVersion "${versionAliases[@]}" )
			fi
		fi
	fi
	versionAliases+=( $version-$serial $version ${aliases[$version]} )

	echo
	cat <<-EOE
		# $serial
		Tags: $(join ', ' "${versionAliases[@]}")
		GitCommit: $commit
		Directory: $version
	EOE
done
