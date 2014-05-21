# TODO

* Figure out why we get duplicate errors.
* JSON pointer error messages.
* Go through and make sure that all error messages are consistent.
* Optimize reference expander for leaf-first expansion (probably more optimal).
* Figure out how to create a JSON pointer to schemas in errors instead of using suboptimal and less accurate ID.

## Testing

* Make all properties separate tests in parser tests.
* Adopt JSON pointer setup convention in parser tests (as seen in validation tests).
* Add more successful cases in validation tests (this process was begun but not finished).
