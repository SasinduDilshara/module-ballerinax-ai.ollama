## Overview

This module offers APIs for connecting with Ollama Large Language Models (LLM).

## Prerequisites

Ensure that your Ollama server is running locally before using this module in your Ballerina application.

## Quickstart

To use the `ai.ollama` module in your Ballerina application, update the `.bal` file as follows:

### Step 1: Import the module

Import the `ai.ollama` module.

```ballerina
import ballerinax/ai.ollama;
```

### Step 2: Intialize the Model Provider

Here's how to initialize the Model Provider:

```ballerina
import ballerina/ai;
import ballerinax/ai.ollama;

final ai:ModelProvider ollamaModel = check new ollama:ModelProvider("ollamaModelName");
```

### Step 4: Invoke chat completion

```ballerina
ai:ChatMessage[] chatMessages = [{role: "user", content: "hi"}];
ai:ChatAssistantMessage response = check ollamaModel->chat(chatMessages, tools = []);

chatMessages.push(response);
```
