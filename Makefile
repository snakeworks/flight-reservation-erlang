EBIN := ebin
SRC := $(wildcard src/*.erl)
TEST := $(wildcard test/*.erl)
BENCH := $(wildcard benchmark/*.erl)

.PHONY: all compile test benchmark clean

all: compile

compile:
	@mkdir -p $(EBIN)
	erlc -I src -o $(EBIN) $(SRC) $(TEST) $(BENCH)

test: compile
	erl -noshell -pa $(EBIN) -eval 'case eunit:test(tests, [verbose]) of ok -> init:stop(0); _ -> init:stop(1) end'

benchmark: compile
	./benchmark/benchmark_runner.sh

clean:
	rm -rf $(EBIN)/*.beam
