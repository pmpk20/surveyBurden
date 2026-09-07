# Contributing to surveyBurden

Thanks for your interest in the package.

## Reporting bugs and requesting features

Open an issue at <https://github.com/pmpk20/surveyBurden/issues>. For a bug,
please include:

- the `surveyBurden` version (`packageVersion("surveyBurden")`) and your R
  version (`R.version.string`);
- a minimal `.qsf` (or a redacted fragment) that reproduces the problem, or the
  exact `burden_report()` / `read_qsf()` call and the error;
- what you expected and what happened.

`.qsf` files can contain question wording you may not want public — a fragment
that still triggers the bug, or an emailed file, is fine.

## Asking for help

Use the issue tracker with the "question" label, or email the maintainer
(address in `DESCRIPTION`).

## Contributing code

1. Open an issue first so we can agree the approach.
2. Fork, branch from `main`, and make your change.
3. Add or update tests in `tests/testthat/`. The suite must pass
   (`devtools::test()`), and `devtools::check()` must be clean.
4. Follow the existing style (the tidyverse style guide; `styler` and `lintr`
   are configured).
5. Update `NEWS.md` and any affected documentation / vignette.
6. Open a pull request describing the change and linking the issue.

By contributing you agree that your contributions are licensed under the
package's MIT licence.

## Scope

`surveyBurden` scores burden from a programmed instrument using the published
GfS / Axhausen scheme. It deliberately does not model respondent behaviour, and
it does not implement alternative burden schemes; proposals that change that
scope should be discussed in an issue before any code.
