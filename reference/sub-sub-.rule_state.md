# Strict access to a rule's traversal state: reading a name the rule did not declare (and that is not a loop count) is an error naming the rule.

Strict access to a rule's traversal state: reading a name the rule did
not declare (and that is not a loop count) is an error naming the rule.

## Usage

``` r
# S3 method for class 'rule_state'
x[[i, ...]]
```

## Arguments

- x:

  A traversal state passed to a `field_rules` function.

- i:

  Name to read.

- ...:

  Unused.
