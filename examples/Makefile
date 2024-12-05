# -*- coding: utf-8 -*-
# ----------------------------------------------------------------------------
# Copyright 2022 ARM Limited or its affiliates
#
# SPDX-License-Identifier: Apache-2.0
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
# ----------------------------------------------------------------------------

CDDL=../cddl/suit-complete.cddl
CDDLTOOL?=cddl

EXAMPLE_SRC+=example0.json
EXAMPLE_SRC+=example1.json
EXAMPLE_SRC+=example2.json
EXAMPLE_SRC+=example3.json
EXAMPLE_SRC+=example4.json
EXAMPLE_SRC+=example5.json

EXAMPLE_TXT=$(patsubst %.json,%.txt,${EXAMPLE_SRC})
EXAMPLE_SUIT=$(patsubst %.json,%.suit,${EXAMPLE_SRC})
EXAMPLE_SIGNED=$(patsubst %.json,%.signed,${EXAMPLE_SRC})
EXAMPLE_SEVERED=$(patsubst %.json,%.severed,${EXAMPLE_SRC})
EXAMPLE_SIGNED_SEVERED=$(patsubst %.json,%.severed-signed,${EXAMPLE_SRC})

ifeq (,${SUITTOOL})
	ifeq (, $(shell which suit-tool))
		ifeq (, $(shell test -f ../suit-tool))
			$(error "No suit-tool in $(PATH)")
		endif
		SUITTOOL=$(shell test -f ../suit-tool/bin/suit-tool)
	else
		SUITTOOL=$(shell which suit-tool)
	endif
endif

all: ${CDDL} ${EXAMPLE_TXT}

.PHONY: ${CDDL}
${CDDL}:
	make -C ../cddl

.PRECIOUS: %.suit
%.suit:%.json #${CDDL}
	@${SUITTOOL} create -i $< -o $@
	@${CDDLTOOL} ${CDDL} validate $@

.PRECIOUS: %.signed
%.signed:%.suit #${CDDL}
	@${SUITTOOL} sign -m $< -k private_key.pem -o $@
	@${CDDLTOOL} ${CDDL} validate $@

.PRECIOUS: %.severed
%.severed:%.suit #${CDDL}
	@${SUITTOOL} sever -a -m $< -o $@
	@${CDDLTOOL} ${CDDL} validate $@

.PRECIOUS: %.severed-signed
%.severed-signed:%.signed #${CDDL}
	@${SUITTOOL} sever -a -m $< -o $@
	@${CDDLTOOL} ${CDDL} validate $@

%.txt:%.severed-signed %.signed %.severed %.suit %.json
	@echo "~~~ cbor-diag" > $@
	@${SUITTOOL} parse -m $< >> $@
	@echo "~~~" >> $@
	@echo "" >> $@
	@sh ./mk-text.sh $@ $^

.PHONY:clean
clean:
	rm ${EXAMPLE_TXT} ${EXAMPLE_SUIT} ${EXAMPLE_SIGNED_SEVERED} ${EXAMPLE_SIGNED} ${EXAMPLE_SEVERED}
