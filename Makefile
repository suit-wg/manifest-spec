DRAFT = draft-ietf-suit-manifest
FN := $(shell grep 'docname: $(DRAFT)' $(DRAFT).md | awk '{print $$2}')

$(FN).txt: $(FN).xml
	xml2rfc $(FN).xml

$(FN).xml: $(DRAFT).md
	kramdown-rfc2629 $(DRAFT).md > $(FN).xml

.PHONY: clean
clean:
	rm -fr $(FN).txt $(FN).xml
