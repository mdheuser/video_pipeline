# Video Pipeline Makefile
.PHONY: help build run run-smoke portable portable-smoke clean rerun check-in \
        docker-clean docker-clean-all docker-clean-volumes

IMG := video-pipeline
IN  ?= ./samples/videos
OUT ?= ./output

help:
	@echo ""
	@echo "Video Pipeline"
	@echo ""
	@echo "USAGE:"
	@echo "  make build"
	@echo "  make run [IN=</path/to/videos>] [OUT=</path/to/output>]"
	@echo "  make run-smoke [IN=</path/to/videos>] [OUT=</path/to/output>]"
	@echo "  make portable [IN=</path/to/videos>] [OUT=</path/to/output>]"
	@echo "  make portable-smoke [IN=</path/to/videos>] [OUT=</path/to/output>]"
	@echo "  make clean [OUT=</path/to/output>]"
	@echo "  make rerun"
	@echo ""
	@echo "DOCKER CLEANUP:"
	@echo "  make docker-clean        (stopped containers + dangling images + build cache)"
	@echo "  make docker-clean-all    (aggressive: remove ALL unused images + cache)"
	@echo "  make docker-clean-volumes(very aggressive: also remove unused volumes)"
	@echo ""
	@echo "DEFAULTS:"
	@echo "  IN  = $(IN)"
	@echo "  OUT = $(OUT)"
	@echo ""
	@echo "EXAMPLES:"
	@echo "  make build"
	@echo "  make run"
	@echo "  make run IN=\"/any/path/to/videos\" OUT=\"/any/path/to/output\""
	@echo "  make portable"
	@echo "  make portable IN=\"/any/path/to/videos\" OUT=\"/any/path/to/output\""
	@echo "  make portable-smoke IN=\"/any/path/to/videos\" OUT=\"/any/path/to/output\""
	@echo "  make docker-clean"
	@echo ""

build:
	@echo "Building Docker image: $(IMG)"
	@docker build -t $(IMG) .

check-in:
	@if [ ! -d "$(IN)" ]; then \
		echo ""; \
		echo "❌ Input directory not found: $(IN)"; \
		echo ""; \
		echo "Try:"; \
		echo "  make run IN=\"/any/path/to/videos\" OUT=\"/any/path/to/output\""; \
		echo "  make portable IN=\"/any/path/to/videos\" OUT=\"/any/path/to/output\""; \
		echo ""; \
		exit 1; \
	fi

run: check-in
	@echo "Running locally (no Docker)."
	@echo "  IN : $(IN)"
	@echo "  OUT: $(OUT)"
	@mkdir -p "$(OUT)"
	@./run.sh "$(IN)" "$(OUT)"

run-smoke: check-in
	@echo "Running locally (no Docker) (SMOKE)."
	@echo "  IN : $(IN)"
	@echo "  OUT: $(OUT)"
	@mkdir -p "$(OUT)"
	@./run.sh "$(IN)" "$(OUT)" --smoke

portable: build check-in
	@echo "Running PORTABLE Docker mode (no bind mounts)."
	@echo "  IN : $(IN)"
	@echo "  OUT: $(OUT)"
	@mkdir -p "$(OUT)"
	@./vp-run-portable.sh "$(IN)" "$(OUT)"

portable-smoke: build check-in
	@echo "Running PORTABLE Docker mode (SMOKE)."
	@echo "  IN : $(IN)"
	@echo "  OUT: $(OUT)"
	@mkdir -p "$(OUT)"
	@./vp-run-portable.sh "$(IN)" "$(OUT)" --smoke

clean:
	@echo "Cleaning generated files..."
	@rm -rf work/*
	@rm -f "$(OUT)/final_video.mp4"
	@echo "✅ Clean done."

rerun: clean run

# ---- Docker cleanup ----
docker-clean:
	@echo "Docker cleanup (safe-ish): stopped containers + dangling images + build cache"
	@docker container prune -f
	@docker image prune -f
	@docker builder prune -f

docker-clean-all:
	@echo "Docker cleanup (aggressive): removes ALL unused images + build cache"
	@docker system prune -a -f

docker-clean-volumes:
	@echo "Docker cleanup (very aggressive): removes unused images + build cache + unused volumes"
	@docker system prune -a --volumes -f
