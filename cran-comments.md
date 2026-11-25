## Resubmission

This is a resubmission. The previous upload included a hidden `.git` file
(a git worktree pointer), flagged by the incoming pre-tests. It is now excluded
in `.Rbuildignore`; the rebuilt tarball contains no hidden files. No other
changes.

## R CMD check results

0 errors | 0 warnings | 1 note

* This is a new submission. The same NOTE lists possibly misspelled words in
  DESCRIPTION; these are explained below.

## Notes

* 'Qualtrics' is the name of a commercial survey platform; the package reads
  its survey files (.qsf).
* Words flagged as possibly misspelled in DESCRIPTION are correct: Axhausen
  and Heimgartner are author surnames, GfS is the acronym of the scoring
  scheme's originator, and qsf is the Qualtrics survey file extension.
* One example (`fetch_qsf()`) is wrapped in `\dontrun{}` because it needs a
  user's Qualtrics API credentials and network access. All other examples run.
* The Qualtrics API path is exercised only in tests that are skipped when
  `QUALTRICS_API_KEY` is not set, so no network access occurs during
  `R CMD check`.

## Test environments

* local: Windows 11, R 4.5.0
* win-builder: R-devel
* GitHub Actions: macOS (release), Windows (release), Ubuntu (devel, release,
  oldrel-1)

## Reverse dependencies

There are currently no downstream dependencies for this package.
