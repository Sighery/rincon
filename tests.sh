#!/usr/bin/env bash
set -euo pipefail

run_test() {
	name="$1"
	echo "===== RUNNING TEST $name ====="

	contentDir="tests/$name/content"
	publicDir="tests/$name/public"
	expectedDir="tests/$name/expected"

	rm -rf "$publicDir"

	HUGO_TEST_CONTENT="$contentDir" hugo \
		--buildDrafts --ignoreCache --quiet \
		--config hugo.toml,tests/hugo.toml \
		--contentDir "$contentDir" \
		--destination "$publicDir"

	while IFS= read -r -d '' file; do
		relative="${file#"$expectedDir"/}"
		actual="$publicDir/$relative"

		if [[ ! -f "$actual" ]]; then
			echo "Missing: $relative"
			exit 1
		fi

		if ! cmp -s "$file" "$actual"; then
			echo "Different: $relative"
			diff -u "$file" "$actual"
			exit 1
		fi
	done < <(find "$expectedDir" -type f -print0)

	echo "===== TEST $name PASSED ====="
}

# RSS should not include draft posts
run_test rss
