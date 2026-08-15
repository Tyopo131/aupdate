#!/usr/bin/env bash

repos_dir="./aupdate.d"
data_dir="$(realpath "./updata")"
repo_dir="$(realpath "./")"
shopt -s nullglob
shopt -p globstar

mkdir -p "$repos_dir" "$data_dir/pkg" "$repo_dir"
atleastone=1
origin_dir="$(realpath "./")"

varset() {
	! [[ -z ${!1+a} ]]
}
build() {
	local repo="$1"
	if ! [[ -z "$2" ]]; then
		printf "Building with toolchain. RPFrom: %s\n" "$(realpath_from $origin_dir $2)"
		local toolchain="-DCMAKE_TOOLCHAIN_FILE=$(realpath_from "$origin_dir" "$2")"
	else
		local toolchain=""
	fi
	local tc_name="$(basename "$2")"
	printf "Using toolchain: %s\n" "$toolchain"
	cmake -S . -DCPACK_PACKAGE_FILE_NAME=package -B build-"$tc_name" "$toolchain"
	cmake --build build-"$tc_name"
	cd build-"$tc_name"
	cpack
	mv ./package.deb "$data_dir/pkg/$(basename "$repo")-$tc_name"
	cd ..
}
realpath_from() {
	(cd "$1" && realpath "$2")
}
if ! command -v git || ! command -v curl || ! command -v jq || ! command -v cmake || ! command -v cpack || ! command -v reprepro; then
	printf "Requires working ready-to-build 'cmake', 'cpack', 'git', 'jq', 'reprepro' and 'curl' to be in path\n"
	exit
fi

for repo in "$repos_dir/"*; do
	printf "Processing $repo\n"
	. "$repo"
	if ! varset owner || ! varset name ; then
		printf "Skipping repo '%s' as it lacks the 'owner' and/or 'name' property, but we need both.\n" "$repo"
		continue
	fi
	tagname="${tag:-auto-update-apt-repo}"
	suite="${suite:-untested}"
	oldcommit=""
	usedefaulttc="${use_default_toolchain:-1}"
	if [[ -f "$data_dir/$(basename "$repo")_last_update" ]]; then
		oldcommit="$(cat "$data_dir/$(basename "$repo")_last_update")"
	fi
	newcommit="$(curl -s "https://api.github.com/repos/$owner/$name/git/refs/tags/$tagname" | jq .object.sha)"
	printf "DEBUG: New: %s, Old: %s\n" "$newcommit" "$oldcommit"

	if [[ "$newcommit" == "null" || -z "$newcommit" ]]; then
		printf "ERROR: Couldn't get commit...\n"
		continue
	fi
	if [[ "$newcommit" == "$oldcommit" ]]; then
		printf "Repo %s unchanged, skipping\n" "$repo"
		continue
	fi
	old_dir="$PWD"
	repodir="$data_dir/repos/$repo"
	mkdir -p "$repodir"
	cd "$repodir"
	if [[ -d "$repodir/.git" ]]; then
		echo "TOPLEVEL: $(git -C "$repodir" rev-parse --show-toplevel)"
		printf "Switching to origin/HEAD\n"
		git fetch
		git fetch --tags --force
		git switch origin/HEAD --detach
	else
		git clone https://www.github.com/"$owner"/"$name" "$repodir"
	fi
	printf "Switching to new commit, SHA: %s\n" "$newcommit"
	git switch "$(printf "%s" "$newcommit" | tr -d "\"")" --detach
	for tc in "${toolchains[@]}"; do
		build "$repo" "$tc"
	done
	if [[ "$usedefaulttc" -gt 0 ]]; then
		build "$repo"
	fi
	printf "%s" "$newcommit" > "$data_dir/$(basename "$repo")_last_update"
	cd "$old_dir"
	atleastone=0
done
if [[ "$atleastone" -eq 0 ]]; then
	cd "$repo_dir"
	reprepro --ignore=extension includedeb untested "$data_dir/pkg"/*
fi
