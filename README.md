LLM_CHAT plugin needs a running local ollama docker container or CopilotChat.nvim.
For local use, you need to have a running ollama docker container with a model downloaded.

Steps:

docker volume create ollama

docker run -d --name ollama \
  -p 11434:11434 \
  -v ollama:/root/.ollama \
  ollama/ollama
  
docker exec -it ollama ollama pull llama3.2:3b

Test:

curl http://localhost:11434/api/generate -d '{
  "model": "llama3.2:3b",
  "prompt": "Say hi in one short sentence.",
  "stream": false
}'
