# qwen 3.8 27b server — llama.cpp on Apple Silicon M4

# --- model configuration -----------------------------------------------------
MAIN_GGUF      := weights/Qwen3.8-27B-UD-Q4_K_M.gguf
MMPROJ_GGUF    := weights/mmproj-F16.gguf
DRAFTER_GGUF   := weights/Qwen3.8-27B-DFlash2-Q4_K_M.gguf

HF_MAIN_REPO    := unsloth/Qwen3.8-27B-GGUF
HF_MMPROJ_FILE  := mmproj-F16.gguf
HF_DRAFTER_REPO := incoai/Qwen3.8-27B-DFlash2-GGUF

# --- server configuration ----------------------------------------------------
CTX        := 262144          # 256k context
PORT       := 8080
HOST       := 127.0.0.1
LOGFILE    := logs/llama-server.log
SPEC_NMAX  := 7               # dflash2 drafts a whole block per pass

SERVER     := llama-server

.PHONY: all download serve stop test test-image bench clean

all: download

# --- weights -----------------------------------------------------------------
$(MAIN_GGUF):
	@mkdir -p weights
	curl -fL -C - -o $@ https://huggingface.co/$(HF_MAIN_REPO)/resolve/main/$(notdir $@)

$(MMPROJ_GGUF):
	@mkdir -p weights
	curl -fL -C - -o $@ https://huggingface.co/$(HF_MAIN_REPO)/resolve/main/$(HF_MMPROJ_FILE)

$(DRAFTER_GGUF):
	@mkdir -p weights
	curl -fL -C - -o $@ https://huggingface.co/$(HF_DRAFTER_REPO)/resolve/main/$(notdir $@)

download: $(MAIN_GGUF) $(MMPROJ_GGUF) $(DRAFTER_GGUF)
	@ls -lh weights/

# --- serving -----------------------------------------------------------------
serve: download
	@mkdir -p logs
	$(SERVER) \
	  -m $(MAIN_GGUF) \
	  --mmproj $(MMPROJ_GGUF) \
	  -md $(DRAFTER_GGUF) \
	  --spec-type draft-dflash \
	  --spec-draft-n-max $(SPEC_NMAX) \
	  -c $(CTX) \
	  -fa on \
	  -ctk q8_0 -ctv q8_0 \
	  --host $(HOST) --port $(PORT) \
	  -ngl 99 \
	  --log-file $(LOGFILE)

serve-fg: download
	$(MAKE) serve

stop:
	-pkill -f "llama-server .*$(MAIN_GGUF)" || true

# --- testing -----------------------------------------------------------------
test:
	curl -s http://$(HOST):$(PORT)/v1/chat/completions -H "Content-Type: application/json" -d '{ \
	  "messages": [{"role": "user", "content": "Why is the sky blue? One paragraph."}], \
	  "max_tokens": 200 \
	}' | python3 -c "import json,sys; print(json.load(sys.stdin)['choices'][0]['message']['content'])"

test-image: assets/sample.png
	@python3 -c " \
	import base64, json, urllib.request; \
	b64 = base64.b64encode(open('assets/sample.png','rb').read()).decode(); \
	req = urllib.request.Request('http://$(HOST):$(PORT)/v1/chat/completions', \
	  data=json.dumps({'messages':[{'role':'user','content':[{'type':'text','text':'Describe this image briefly.'},{'type':'image_url','image_url':{'url':'data:image/png;base64,'+b64}}]}],'max_tokens':100}).encode(), \
	  headers={'Content-Type':'application/json'}); \
	print(json.load(urllib.request.urlopen(req))['choices'][0]['message']['content'])"

assets/sample.png:


bench:
	llama-bench -m $(MAIN_GGUF) -p 512 -n 256 -md $(DRAFTER_GGUF) -st draft-dflash

clean:
	rm -rf weights logs
