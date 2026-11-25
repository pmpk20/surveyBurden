## R CMD check results

0 errors | 0 warnings | 1 note

* This is a new submission.

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
