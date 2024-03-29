FRAMEWORKS = -framework Contacts -framework Foundation
#CC = cc -framework Foundation
CC = cc -fobjc-arc
LDFLAGS = $(FRAMEWORKS) -fobjc-arc
#CFLAGS = -fobjc-arc -g
#CFLAGS = -fobjc-arc -arch x86_64
DISTDIR=/usr/local

PROGRAMS = cnfind tel2name cn2vcf

.PHONY: all clean install

all:	$(PROGRAMS)

clean:
	rm -f $(PROGRAMS) *.o *~

install:	$(PROGRAMS)
	install -m 0755 $(PROGRAMS) $(DISTDIR)/bin
