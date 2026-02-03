#Exclude working directory and outoput file
.PHONY: run clean rerun

run:
	./run.sh

clean:
	@echo "Cleaning generated files..."
	@rm -rf work/*
	@rm -f output/final_video.mp4
	@echo "✅ Clean done."

rerun:
	clean run