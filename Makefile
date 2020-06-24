all:
	pandoc README.md -o README.html --highlight-style=monochrome -t html+grid_tables

view: all
	xdg-open README.html
