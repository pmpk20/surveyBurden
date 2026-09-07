## R CMD check results

0 errors | 0 warnings | 1 note

## Notes

* This is a new submission.
* The Qualtrics API path (`fetch_qsf()`) is exercised only in tests that are
  skipped without `QUALTRICS_API_KEY` set; no network access occurs during
  `R CMD check`.

## Test environments

* local: Windows 11, R 4.5.0 -- 0 errors | 0 warnings | 0 notes
* win-builder: R-devel
