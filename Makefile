# file:        Makefile
# author:      Andrea Vedaldi
# description: Build everything

# AUTORIGHTS

# This makefile builds VLFeat on modern UNIX boxes with the GNU
# toolchain. Mac OS X and Linux are explicitly supported, and support
# for similar architectures can be easily added.
#
# Usually, compiling VLFeat reduces to typing
#
# > make
#
# The makefile attempts to automatically determine the host
# architecture. If this fails, or if the architecture is ambiguous,
# the architecture can be set by specifying the ARCH variable. For
# instance:
#
# > make ARCH=maci64
#
# builds VLFeat for Mac OS X Intel 64bit. Other useful variables include
#
#   ARCH     Choose the active architecture (one of maci, maci64, glx, a64).
#   DEBUG    Define in order to compile a debugging version.
#   MEX      Path to MATLAB MEX compiler program (e.g. ${MATLABROOT}/bin/mex).
#
# The following targets may also be useful:
#
# > make clean      # removes intermediate files
# > make archclean  # removes all products for the active architecture
# > make distclean  # removes all products
# > make octave-all # compiles GNU Octave MEX files (experimental)
#
# As VLFeat is compsed of different parts (DLL, command line
# utilities, MATLAB interface, Octave interface) so the makefile is
# divided in components, located in make/*.mak. Please check out the
# corresponding files in order to adjust any parameter that may not.

.PHONY : all
all:

# --------------------------------------------------------------------
#                                                       Error Messages
# --------------------------------------------------------------------

err_no_arch  =
err_no_arch +=$(shell echo "** Unknown host architecture '$(UNAME)'. This identifier"   1>&2)
err_no_arch +=$(shell echo "** was obtained by running 'uname -sm'. Edit the Makefile " 1>&2)
err_no_arch +=$(shell echo "** to add the appropriate configuration."                   1>&2)
err_no_arch +=config

err_internal  =$(shell echo Internal error)
err_internal +=internal

err_spaces  = $(shell echo "** VLFeat root dir VLDIR='$(VLDIR)' contains spaces."  1>&2)
err_spaces += $(shell echo "** This is not supported due to GNU Make limitations." 1>&2)
err_spaces +=spaces

# --------------------------------------------------------------------
#                                             Auto-detect architecture
# --------------------------------------------------------------------

Darwin_PPC_ARCH := mac
Darwin_Power_Macintosh_ARCH := mac
Darwin_i386_ARCH := maci
Linux_i386_ARCH := glx
Linux_i686_ARCH := glx
Linux_unknown_ARC := glx
Linux_x86_64_ARCH := a64

UNAME := $(shell uname -sm)
ARCH ?= $($(shell echo "$(UNAME)" | tr \  _)_ARCH)

# sanity check
ifeq ($(ARCH),)
die:=$(error $(err_no_arch))
endif

ifneq ($(VLDIR),$(shell echo "$(VLDIR)" | sed 's/ //g'))
die:=$(error $(err_spaces))
endif

# --------------------------------------------------------------------
#                                                        Configuration
# --------------------------------------------------------------------

VLDIR ?= .
CC ?= cc

CFLAGS += -std=c99
CFLAGS += -Wall -Wextra
CFLAGS += -Wno-unused-function -Wno-long-long -Wno-variadic-macros
CFLAGS += -DVL_ENABLE_THREADS
CFLAGS += -DVL_ENABLE_SSE2
CFLAGS += -I$(VLDIR)

CFLAGS += $(if $(DEBUG), -DVL_DEBUG -O0 -g, -DNDEBUG -O3)
CFLAGS += $(if $(PROFILE), -g,)

# Architecture specific ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# Mac OS X Intel 32
ifeq ($(ARCH),maci)
SDKROOT := /Developer/SDKs/MacOSX10.5.sdk
CFLAGS += -m32 -isysroot $(SDKROOT)
LDFLAGS += -lm -mmacosx-version-min=10.5
endif

# Mac OS X Intel 64
ifeq ($(ARCH),maci64)
SDKROOT := /Developer/SDKs/MacOSX10.5.sdk
CFLAGS += -m64 -isysroot $(SDKROOT)
LDFLAGS += -lm -mmacosx-version-min=10.5
endif

# Linux-32
ifeq ($(ARCH),glx)
CFLAGS  += -march=i686
LDFLAGS += -lm -Wl,--rpath,\$$ORIGIN/
endif

# Linux-64
ifeq ($(ARCH),a64)
LDFLAGS += -lm -Wl,--rpath,\$$ORIGIN/
endif

# --------------------------------------------------------------------
#                                                            Functions
# --------------------------------------------------------------------

# $(call if-like,FILTER,WHY,WHAT)
define if-like
$(if $(filter $(1),$(2)),$(3))
endef

# $(call dump-var,VAR) pretty-prints the content of a variable VAR on
# multiple columns
ifdef VERB
define dump-var
@echo $(1) =
@echo $($(1)) | sed 's/\([^ ][^ ]* [^ ][^ ]*\) */\1#/g' | \
tr '#' '\n' | column -t | sed 's/\(.*\)/  \1/g'
endef
else
define dump-var
@printf "%15s = %s\n" "$(1)" \
"$$(echo '$($(1))' | sed -e 's/[^ ][^ ]* /\.\.\./3' -e 's/\.\.\..*$$/\.\.\./g')"
endef
endif

# $(call echo-var,VAR) pretty-prints the content of a variable VAR on
# one line
define echo-var
@printf "%15s = %s\n" "$(1)" "$($(1))"
endef

# $(call print-command, CMD, TGT) prints a message
define print-command
@printf "%15s %s\n" "$(strip $(1))" "$(strip $(2))"
endef

# $(call C, CMD) runs $(CMD) silently
define C
@$(call print-command, $(1), "$(@)")
@quiet ()                                                            \
{                                                                    \
    local cmd out err ;					             \
    cmd="$($(1))";                                                   \
    out=$$($${cmd} "$${@}" 2>&1) ;                                   \
    err=$${?} ;                                                      \
    if test $${err} -gt 0 ; then                                     \
        echo "******* Offending Command:";                           \
        printf "%s" "$${cmd}" ;                                      \
	for i in "$${@}" ; do printf " '%s'" "$$i" ; done ;          \
	echo ;                                                       \
        echo "******* Error Code: $${err}";                          \
	echo "******* Command Output:";                              \
        echo "$${out}";                                              \
    fi;                                                              \
    echo "$${out}" | grep [Ww]arning ;                               \
    return $${err};                                                  \
} ; quiet
endef

# If verbose print everything
ifdef VERB
C = $($(1))
endif

# rule to create a directory
.PRECIOUS: %/.dirstamp
%/.dirstamp :
	@printf "%15s %s\n" MK "$(dir $@)"
	@mkdir -p $(dir $@)
	@echo "Directory generated by make." > $@

# $(call gendir, TARGET, DIR1 DIR2 ...) creates a target TARGET-dir that
# triggers the creation of the directories DIR1, DIR2
define gendir
$(1)-dir=$(foreach x,$(2),$(x)/.dirstamp)
endef

# --------------------------------------------------------------------
#                                                                Build
# --------------------------------------------------------------------

# Each Makefile submodule appends appropriate dependencies to the all,
# clean, archclean, distclean, and info targets. In addition, it
# appends to the deps and bins variables the list of .d files (to be
# inclued by make as auto-dependencies) and the list of files to be
# added to the binary distribution.

include make/dll.mak
include make/bin.mak
include make/matlab.mak
include make/octave.mak
include make/doc.mak
include make/dist.mak

.PHONY: clean, archclean, distclean, info, autorights
no_dep_targets += clean archclean distclean info autorights

clean:
	rm -f  `find . -name '*~'`
	rm -f  `find . -name '.DS_Store'`
	rm -f  `find . -name '.gdb_history'`
	rm -f  `find . -name '._*'`
	rm -rf ./results

archclean: clean

distclean:

info :
	@echo "************************************* General settings"
	$(call echo-var,DEBUG)
	$(call echo-var,VER)
	$(call echo-var,ARCH)
	$(call echo-var,CFLAGS)
	$(call echo-var,LDFLAGS)
	$(call echo-var,CC)
	@printf "\nThere are %s lines of code.\n" \
	`cat $(m_src) $(mex_src) $(dll_src) $(dll_hdr) $(bin_src) | wc -l`

autorights: distclean
	autorights                                                   \
	  toolbox vl                                                 \
	  --recursive                                                \
	  --verbose                                                  \
	  --template docsrc/copylet.txt                              \
	  --years 2007-10                                            \
	  --authors "Andrea Vedaldi and Brian Fulkerson"             \
	  --holders "Andrea Vedaldi and Brian Fulkerson"             \
	  --program "VLFeat"

# --------------------------------------------------------------------
#                                                 Include dependencies
# --------------------------------------------------------------------

.PRECIOUS: $(deps)

ifeq ($(filter $(no_dep_targets), $(MAKECMDGOALS)),)
-include $(deps)
endif
