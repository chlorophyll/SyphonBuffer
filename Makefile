FRAMEWORK_SEARCH_PATH=-FFrameworks
FRAMEWORKS=-framework OpenGL -framework Foundation -framework Cocoa -framework Syphon

SyphonBuffer: SyphonBuffer.m LineReader.m
	clang $(FRAMEWORK_SEARCH_PATH) $(FRAMEWORKS) $^ -o $@
