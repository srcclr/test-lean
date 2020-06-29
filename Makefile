BUILD = build
MAKEFILE = Makefile
OUTPUT_FILENAME = oct-wave
HTML_OUTPUT_FILENAME = index
METADATA = metadata.yaml
CHAPTERS = chapters/*.md
TOC = --toc --toc-depth=2
IMAGES_FOLDER = images
IMAGES = $(IMAGES_FOLDER)/*
COVER_IMAGE = $(IMAGES_FOLDER)/cover.jpg
LATEX_CLASS = report
MATH_FORMULAS = --webtex
CSS_FILE = style.css
CSS_ARG = --css=$(CSS_FILE)
METADATA_ARG = --metadata-file=$(METADATA)
ARGS = $(TOC) $(MATH_FORMULAS) $(CSS_ARG) $(METADATA_ARG)

all:	book

book:	epub pdf html

honkit:
	npm ci
	npm run honkit -- build
	npm run honkit -- epub . book.epub
	npm run honkit -- mobi . book.mobi

clean:
	rm -r $(BUILD)

epub:	$(BUILD)/epub/$(OUTPUT_FILENAME).epub

html:	$(BUILD)/html/$(HTML_OUTPUT_FILENAME).html

pdf:	$(BUILD)/pdf/$(OUTPUT_FILENAME).pdf

$(BUILD)/epub/$(OUTPUT_FILENAME).epub:	$(MAKEFILE) $(METADATA) $(CHAPTERS) $(CSS_FILE) $(IMAGES) \
					$(COVER_IMAGE)
	mkdir -p $(BUILD)/epub
	pandoc $(ARGS) --epub-cover-image=$(COVER_IMAGE) -o $@ $(CHAPTERS)

$(BUILD)/html/$(HTML_OUTPUT_FILENAME).html:	$(MAKEFILE) $(METADATA) $(CHAPTERS) $(CSS_FILE) $(IMAGES)
	mkdir -p $(BUILD)/html
	pandoc $(ARGS) --standalone --to=html5 -o $@ $(CHAPTERS) --template templates/default.html --toc -V toctitle:'Table of Contents'
	cp -R $(IMAGES_FOLDER)/ $(BUILD)/html/$(IMAGES_FOLDER)/
	cp $(CSS_FILE) $(BUILD)/html/$(CSS_FILE)

$(BUILD)/pdf/$(OUTPUT_FILENAME).pdf:	$(MAKEFILE) $(METADATA) $(CHAPTERS) $(CSS_FILE) $(IMAGES)
	mkdir -p $(BUILD)/pdf
	pandoc $(ARGS) -V documentclass=$(LATEX_CLASS) -o $@ $(CHAPTERS)
