# This directory and this little Makefile let you run automated tests of the
# optional semicolon prototype on a corpus of code. Given a directory "original"
# containing the corpus, you can run these tasks:

# We mostly want to validate this on idiomatic code. The various language and
# Dart tool tests often have deliberately bizarre code to test edge cases. Also,
# the test framework requires special marker comments in specific odd places.
#
# Delete all of those since they aren't relevant or representative.
#
# There is also some duplication where a package is in multiple locations.
# Delete most of those.
remove_stuff:
	rm -rf original/sdk/tests
	rm -rf original/sdk/pkg/analyzer/test
	rm -rf original/sdk/pkg/analyzer_cli/test
	rm -rf original/sdk/pkg/analysis_server/test
	rm -rf original/sdk/pkg/dev_compiler/test
	rm -rf original/sdk/pkg/front_end/testcases
	rm -rf original/sdk/pkg/kernel/test
	rm -rf original/sdk/runtime/tests
	rm -rf original/sdk/third_party/pkg
	rm -rf original/sdk/third_party/pkg_tested
	rm -rf original/packages/front_end-0.1.6/testcases

# "original" -> "strip-original"
#
# Runs a little script that mechanically removes semicolons from the corpus but
# doesn't make any other formatting changes. The resulting code is a corpus
# that looks like what a Dart user would write in an optional semicolon world.
strip-original:
	rm -rf strip-original
	dart ../../scripts/bin/strip_semicolons.dart original strip-original

# "original" -> "strip-baseline"
#
# Runs a little script that mechanically removes semicolons from the
# baseline-formatted corpus. The resulting code is a corpus
# that looks like what a Dart user would migrate their code to in an optional
# semicolon world.
strip-baseline:
	rm -rf strip-original
	dart ../../scripts/bin/strip_semicolons.dart baseline strip-baseline

# "original" -> "baseline"
#
# Runs dartfmt on the corpus using the current Dart grammar. The actual
# formatting isn't relevant. We just use this as a way to serialize the AST so
# that we can visualize how the front end "sees" the code.
#
# This produces a baseline that we can compare other outputs against. A
# difference between this and another output shows places where the parser
# produces a different AST -- where the grammar interprets the code in a
# different way.
baseline:
	rm -rf baseline
	dart ../../code/dart_style_strict_semi/bin/format.dart -o baseline original

# "baseline" -> "parse-baseline"
#
# Runs dartfmt on "baseline" using the prototype optional semicolon parser. in
# other words, this goes through dartfmt twice, once with the old parser and
# once with the new.
#
# Differences between this and "parse-original" generally show places where
# existing code can be fixed simply by running dartfmt on it. (It's also
# possible for dartfmt to *break* things that were hand-formatted in a way that
# plays nicer with optional semicolons, but I'm not aware of examples of that.)
parse-baseline:
	rm -rf parse-baseline
	dart ../../code/dart_style_strict_semi/bin/format.dart --optional-semicolons \
			-o parse-baseline baseline

# "original" -> "parse-original"
#
# Runs dartfmt on "original" using the prototype optional semicolon parser. This
# shows how existing Dart code which contains semicolons is viewed by the new
# grammar that treats newlines significantly in some places.
#
# Differences between this and "baseline" show "breaking changes", places where
# existing Dart code has a different interpretation under the new grammar.
parse-original:
	rm -rf parse-original
	dart ../../code/dart_style_strict_semi/bin/format.dart --optional-semicolons \
			-o parse-original original

# "strip-original" -> "parse-strip-original"
#
# Runs dartfmt on "strip-original" using the prototype optional semicolon
# parser. This shows how new Dart code without semicolons is viewed by the new
# grammar.
#
# Differences between this and "parse-original" show places where removing a
# semicolon causes the code to be parsed differently.
parse-strip-original:
	rm -rf parse-strip-original
	dart ../../code/dart_style_strict_semi/bin/format.dart --optional-semicolons \
			-o parse-strip-original strip-original

# "strip-baseline" -> "parse-strip-baseline"
#
# Runs dartfmt on "strip-baseline" using the prototype optional semicolon
# parser. This shows how new Dart code without semicolons is viewed by the new
# grammar.
#
# Differences between this and "parse-baseline" show places where removing a
# semicolon causes the code to be parsed differently.
parse-strip-baseline:
	rm -rf parse-strip-baseline
	dart ../../code/dart_style_strict_semi/bin/format.dart --optional-semicolons \
			-o parse-strip-baseline strip-baseline

.PHONY: baseline parse-baseline parse-original parse-strip-baseline \
	parse-strip-original remove_stuff strip-baseline strip-original
