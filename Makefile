.PHONY: build run test smoke
build:
	./scripts/build.sh
run:
	./scripts/run.sh
test:
	./scripts/test.sh
smoke: build
	./build/Fake.app/Contents/MacOS/Fake --smoke-test
