# Stress test AI-Agent

## Idea

The AI agent takes an existing architecture design (or parts of it) and elaborates on the possible bottlenecks. It does so by using all available context information like business requirements (e.g. non-functional like number of expected data entities passing a cloud function and so on) but also it's integrated knowledage about archietcture. Later it could also do extended web searches to pull in more current knowledge.

Later, the knowledge/definition of what we expected from stress tests (the baseline) could either be fine-tuned, RAG'ed or trained into the LLM.

### Questions

- What is the best origin format for the architecture design to be readable by an LLM? e.g. `plantUML` or rather visual formats (images, SVGs, ...)
=> Answered in other ChatGPT chat: always use text based

