# EXTENSION = pg_feedback
# DATA = pg_feedback--0.0.1.sql
# OBJS = pg_feedback.o
# # If PG_CONFIG is not set, try the default build folder.
# PG_CONFIG    ?= pg_config
# PGXS := $(shell $(PG_CONFIG) --pgxs)
# include $(PGXS)
EXTENSION    = pg_feedback
# MODULE_big = pg_feedback
EXTVERSION   = $(shell grep default_version $(EXTENSION).control | sed -e "s/default_version[[:space:]]*=[[:space:]]*'\([^']*\)'/\1/")
# TESTS        = $(wildcard test/sql/*.sql)
# REGRESS      = $(patsubst test/sql/%.sql,%,$(TESTS))
# REGRESS_OPTS = --inputdir=test
MODULES      = $(patsubst %.c,%,$(wildcard *.c))
PG_CONFIG    ?= pg_config

override PG_CFLAGS += -std=gnu11

all:

release-zip: all
	git archive --format zip --prefix=$(EXTENSION)-$(EXTVERSION)/ --output ./$(EXTENSION)-$(EXTVERSION).zip HEAD
	unzip ./$(EXTENSION)-$(EXTVERSION).zip
	rm ./$(EXTENSION)-$(EXTVERSION).zip
	sed -i -e "s/__VERSION__/$(EXTVERSION)/g"  ./$(EXTENSION)-$(EXTVERSION)/META.json
	zip -r ./$(EXTENSION)-$(EXTVERSION).zip ./$(EXTENSION)-$(EXTVERSION)/
	rm ./$(EXTENSION)-$(EXTVERSION) -rf


DATA = $(wildcard *--*.sql)
PGXS := $(shell $(PG_CONFIG) --pgxs)
include $(PGXS)
