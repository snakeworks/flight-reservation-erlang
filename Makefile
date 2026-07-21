EBIN := ebin
SRC := $(wildcard src/*.erl)
TEST := $(wildcard test/*.erl)

.PHONY: all compile test clean

all: compile

compile:
	@mkdir -p $(EBIN)
	erlc -I src -o $(EBIN) $(SRC) $(TEST)

test: compile
	erl -noshell -pa $(EBIN) -eval 'case eunit:test(tests, [verbose]) of ok -> init:stop(0); _ -> init:stop(1) end'

clean:
	rm -rf $(EBIN)/*.beam
