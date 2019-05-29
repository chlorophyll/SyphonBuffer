FRAMEWORK_SEARCH_PATH=-F../Frameworks
FRAMEWORKS=-framework OpenGL -framework Foundation -framework Cocoa -framework Syphon
CFLAGS=-Wno-deprecated-declarations

.PHONY: clean

SyphonBuffer: SyphonDispatcher.m LineReader.m BufferClient.m
	clang $(CFLAGS) $(FRAMEWORK_SEARCH_PATH) $(FRAMEWORKS) $^ -o $@

clean:
	rm SyphonBuffer
