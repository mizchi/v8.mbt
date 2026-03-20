# MoonBit Project Commands

target := "native"

default: check test

fmt:
    moon fmt

fmt-check:
    moon fmt --check

bootstrap:
    bash src/scripts/build-rusty-v8.sh _build/bootstrap/rusty_v8.stamp

check:
    moon check --deny-warn --target {{target}}

test:
    moon test --target {{target}}

test-update:
    moon test --update --target {{target}}

run:
    moon run src/main --target {{target}}

info:
    moon info

info-check:
    moon info
    git diff --exit-code -- ':(glob)**/*.generated.mbti'

clean:
    moon clean

release-check: fmt info check test

ci: fmt-check info-check check test
