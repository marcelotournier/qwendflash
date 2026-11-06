# qwen 3.8 27b server

### non negotiables
- qwen 3.8 27b q4 k m from unsloth
- dflash2 drafter from incoai/Qwen3.8-27B-DFlash2)
- download weights and drafter from huggingface
- 256k context
- image and text input
- llamacpp built and optimized for apple silicon m4

### development
- this is a live doc modify as you go
- commit push as you go
- git ignore for venv, weights, logfiles, etc
- makefile automation to streamline model serving
- create a repo with github user marcelotournier
- test the model with pi on a new tmux window (use current session if on tmux)
- use websearch if stuck on a rut
