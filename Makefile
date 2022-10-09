DMD      := dmd
DMDFLAGS := 

.PHONY: install

importsort-d:
	dmd -of=importsort-d importsort.d

install: importsort-d
	install importsort-d /usr/bin/