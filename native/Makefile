FRAMEWORK_SEARCH_PATH=-F./Frameworks
FRAMEWORKS=-framework OpenGL -framework Foundation -framework Cocoa -framework Syphon
CFLAGS=-Wno-deprecated-declarations

.PHONY: clean

bin/SyphonBuffer: SyphonDispatcher.m LineReader.m BufferClient.m
	mkdir -p bin
	clang $(CFLAGS) $(FRAMEWORK_SEARCH_PATH) $(FRAMEWORKS) $^ -o $@

clean:
	rm bin/SyphonBuffer
