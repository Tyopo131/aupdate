#!/usr/bin/env bash

repos_dir="./aupdate.d"
data_dir="$(realpath "./updata")"
repo_dir="$(realpath "./")"
shopt -s nullglob
shopt -p globstar

mkdir -p "$repos_dir" "$data_dir/pkg" "$repo_dir"
atleastone=1
varset() {
	! [[ -z ${!1+a} ]]
}

if ! command -v git || ! command -v curl || ! command -v jq || ! command -v cmake || ! command -v cpack || ! command -v reprepro; then
	printf "Requires working ready-to-build 'cmake', 'cpack', 'git', 'jq', 'reprepro' and 'curl' to be in path"
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
	if [[ -f "$data_dir/$(basename "$repo")_last_update" ]]; then
		oldcommit="$(cat "$data_dir/$(basename "$repo")_last_update")"
	fi
	newcommit="$(curl -s "https://api.github.com/repos/$owner/$name/git/refs/tags/$tagname" | jq .object.sha)"
	printf "DEBUG: New: %s, Old: %s" "$newcommit" "$oldcommit"

	if [[ "$newcommit" == "null" || -z "$newcommit" ]]; then
		printf "ERROR: Couldn't get commit..."
		continue
	fi
	if [[ "$newcommit" == "$oldcommit" ]]; then
		printf "Repo %s unchanged, skipping" "$repo"
		continue
	fi
	old_dir="$PWD"
	repodir="$data_dir/repos/$repo"
	mkdir -p "$repodir"
	cd "$repodir"
	if git --is-inside-work-tree 1>/dev/null 2>&1; then
		git pull
	else
		git clone https://www.github.com/"$owner"/"$name" "$repodir"
	fi
	git switch "$newcommit" --detach
	cmake -S . -DCPACK_PACKAGE_FILE_NAME=package -B build
	cmake --build build
	cd build
	cpack
	mv ./package.deb "$data_dir/pkg/$(basename "$repo")"
	printf "%s" "$newcommit" > "$data_dir/$(basename "$repo")_last_update"
	cd "$old_dir"
	atleastone=0
done
if [[ "$atleastone" -eq 0 ]]; then
	cd "$repo_dir"
	reprepro --ignore=extension includedeb untested "$data_dir/pkg"/*
fi
