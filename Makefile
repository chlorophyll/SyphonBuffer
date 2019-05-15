FRAMEWORK_SEARCH_PATH=-FFrameworks
FRAMEWORKS=-framework OpenGL -framework Foundation -framework Cocoa -framework Syphon

main: main.m
	clang $(FRAMEWORK_SEARCH_PATH) $(FRAMEWORKS) $^ -o $@
