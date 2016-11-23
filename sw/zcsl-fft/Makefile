CC=gcc -DDEBUG
APP=zcsl-fft
LIBCXL_DIR=../libcxl
PSLSE_DIR=../pslse


LIBCXL_LIBS=$(LIBCXL_DIR)/libcxl.a
PSLSE_LIBCXL=$(PSLSE_DIR)/libcxl
PSLSE_LIBCXL_LIBS=$(PSLSE_LIBCXL)/libcxl.a
PSLSE_CXL_H=$(PSLSE_DIR)/common


LINKFLAGS=-lm
CFLAGS=-URUNSIM
SIMCFLAGS=-pthread -DRUNSIM

all: $(APP)-sim
	
$(APP)-sim: $(APP).c
	$(CC) -o $@ $(SIMCFLAGS) -I$(PSLSE_LIBCXL) -I$(PSLSE_CXL_H) $^ $(PSLSE_LIBCXL_LIBS) $(LINKFLAGS)

$(APP)-hw: $(APP).c
	$(CC) -o $@ $(CFLAGS) -I$(LIBCXL_DIR) $^ $(LIBCXL_LIBS) $(LINKFLAGS)

clean:
	rm -f $(APP)-sim $(APP)-hw transformed.dat source.dat



