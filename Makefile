.DEFAULT_GOAL := default

include site.mk

# BEGIN: Primary tasks

default: clean prepare license_check format analyze test coverage doc_site
.PHONY: default

pre_commit: format_check analyze license_check test
.PHONY: pre_commit

cicd: default
.PHONY: cicd

# END: Primary tasks

format:
	dart format lib/ test/
.PHONY: format

format_check:
	dart format --output=none --set-exit-if-changed lib/ test/
.PHONY: format_check

analyze:
	flutter analyze
.PHONY: analyze

checks: coverage.log license_check
.PHONY: checks

test:
	flutter test
.PHONY: test

license_check:
	cat addlicense_config.txt | xargs addlicense --check

license_add:
	cat addlicense_config.txt | xargs addlicense

coverage: coverage.log
.PHONY: coverage

coverage.log: lib/** test/**
	flutter test --coverage
	rm -rf site/coverage
	mkdir -p site/coverage
	genhtml coverage/lcov.info -o site/coverage


# prepare_dart: Dart-only setup — safe on CI runners that lack Flutter.
# prepare_flutter: Full setup including Flutter project pub-gets.
# prepare: Full local setup (delegates to prepare_flutter).
prepare:
	dart pub global activate coverage
	dart pub get
.PHONY: prepare_dart

clean:
	rm -rf site dist coverage build example/build
	rm -f *.log
	dart pub get

.PHONY: clean
