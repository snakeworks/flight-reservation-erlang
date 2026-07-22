EBIN := ebin
SRC := $(wildcard src/*.erl)
TEST := $(wildcard test/*.erl)

.PHONY: all compile test bench1 bench2 bench3 clean

PLIMIT := +P 20000000

all: compile

compile:
	@mkdir -p $(EBIN)
	erlc -I src -o $(EBIN) $(SRC) $(TEST)

test: compile
	erl -noshell -pa $(EBIN) -eval 'case eunit:test(tests, [verbose]) of ok -> init:stop(0); _ -> init:stop(1) end'

bench1: compile
	erl $(PLIMIT) -noshell -pa $(EBIN) -eval 'benchmark:exp1(), init:stop(0).'

bench2: compile
	erl $(PLIMIT) -noshell -pa $(EBIN) -eval 'benchmark:exp2(), init:stop(0).'

bench3: compile
	erl $(PLIMIT) -noshell -pa $(EBIN) -eval 'benchmark:exp3(), init:stop(0).'

clean:
	rm -rf $(EBIN)/*.beam
