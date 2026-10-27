# The datadog branch

The `datadog` branch of 0intro/openscap is the upstream OpenSCAP commit
that `branches.yml` names as the base, plus one commit for every commit of
the branches it lists, cherry-picked in that order. It holds the changes
the Datadog Agent builds OpenSCAP with, and its releases publish the
source tarball the Agent downloads. `datadog.py sync` rebuilds it from the
branches, and `datadog.py check` verifies it. Each of its commits keeps
the author and message of its source and ends with two trailers that name
the source:

	Datadog-Branch: djc/sce-stdin-null
	Datadog-Source: 0123456789abcdef0123456789abcdef01234567

- `branches.yml`: the base, the upstream release it carries, and the
  ordered branches. An entry contributes the commits of its branch beyond
  the base and the earlier entries, so a branch stacked on another
  contributes its own commits: one, or the number its `commits` field
  gives. `pr` names the upstream pull request of a branch, which the
  release notes link.
- `resolve/<branch>.yml`: when the pick of a branch conflicts with the
  branches before it, the texts that replace each conflict block, in order.
- `datadog.py`: `list`, `sync`, `check`, `restack` the branches stacked on
  an amended one, `rebase` onto a new upstream commit, `push` to
  0intro/openscap, `notes` for a release, and `tarball`, which writes the
  source tarball of a commit and its sums.
- `tests/`: `python3 -m unittest discover -s .datadog/tests`.

## Changing a branch

Each change lives on a branch of its own, `djc/<name>`: one commit on
upstream main, or on the branch it builds on, with its test, ready to go
upstream. To add one, push the branch and add its entry after the entries
it builds on. After amending a branch, `datadog.py restack <branch> <old
head>` moves the branches stacked on it. Then `sync`, `check` and `push`:
`push` checks `datadog` again and sends every changed branch in one atomic
`git push`, each under a lease.

## Moving to a new upstream release

When the branches sit on an ancestor of the new release, point `base` at
the release's commit, set `release`, and `sync`: the branches keep their
heads, and a pick that conflicts takes its recorded resolution. To move
the branches themselves, `datadog.py rebase <commit>` rebases every branch
onto the commit, points `base` at it and syncs. Then set `release` by hand
and sync again. Once upstream merges a branch, drop its entry: sync stops
at an entry whose commits the base already holds.

## Releases

A tag `v<release>-dd.<YYYYMMDD>.<N>` on the head of `datadog` makes
`.github/workflows/datadog-release.yml` publish a release. `<release>` is
the upstream release that `release` names, `<YYYYMMDD>` the UTC commit
date of the base, and `<N>` counts the releases on that base, from 1. The
`v` keeps the tags clear of upstream's release workflow, which fires on
tags of the form `1.4.6`.

The workflow checks the branch with `datadog.py check --trailers`, checks
that `release` is the newest upstream release in the history of the base,
writes `openscap-<version>.tar.gz` with `datadog.py tarball`, builds and
tests it on Fedora with warnings as errors, and publishes it with its
`.sha256`, its `.sha512` and `manifest.json`, which lists the base, the
head of every branch and the sums of the tarball.

The tarball holds the files of upstream's source package (`make
package_source`), read from git: the files of the commit and of its
submodules, less `.datadog` and the paths that `CPACK_SOURCE_IGNORE_FILES`
matches. Its entries are sorted, dated at the commit's committer date and
owned by 0, so a commit gives the same tar on every host, and
`manifest.json` records its sha256 as `tar_sha256`. The gzip bytes also
depend on zlib: the workflow compresses in a Fedora image pinned by
digest, where `datadog.py tarball <version> <dir> --rev <tag>` gives the
published bytes again.

A push to `datadog` runs the same check, tarball and build as a dry run,
as version `<release>-dd.<YYYYMMDD>.0`, and keeps the tarball for 14 days.
The workflow refuses a tag whose release exists, so a bad release gets the
next tag.
