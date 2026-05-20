// Copyright (c) 2025 WSO2 LLC (http://www.wso2.com).
//
// WSO2 LLC. licenses this file to you under the Apache License,
// Version 2.0 (the "License"); you may not use this file except
// in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing,
// software distributed under the License is distributed on an
// "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
// KIND, either express or implied.  See the License for the
// specific language governing permissions and limitations
// under the License.

import ballerina/ai;
import ballerina/ai.observe;
import ballerina/http;

# EmbeddingProvider represents a client for generating vector embeddings using Ollama embedding models.
@display {
    label: "Ollama Embedding Provider"
}
public distinct isolated client class EmbeddingProvider {
    *ai:EmbeddingProvider;
    private final http:Client ollamaClient;
    private final string modelType;
    private final readonly & OllamaEmbeddingModelParameters parameters;

    # Initializes the embedding provider with the given connection and model configuration.
    #
    # + modelType - The Ollama embedding model name
    # + serviceUrl - The base URL for the Ollama API endpoint
    # + parameters - Additional embedding model parameters
    # + connectionConfig - Additional connection configuration
    # + return - `nil` on success, otherwise an `ai:Error`
    public isolated function init(@display {label: "Embedding Model Type"} string modelType,
            @display {label: "Service URL"} string serviceUrl = DEFAULT_OLLAMA_SERVICE_URL,
            @display {label: "Ollama Embedding Model Parameters"} *OllamaEmbeddingModelParameters parameters,
            @display {label: "Connection Configuration"} *ConnectionConfig connectionConfig) returns ai:Error? {
        http:ClientConfiguration clientConfig = {...connectionConfig};
        http:Client|error ollamaClient = new (serviceUrl, clientConfig);
        if ollamaClient is error {
            return error("Error while connecting to the embedding model", ollamaClient);
        }
        self.ollamaClient = ollamaClient;
        self.modelType = modelType;
        self.parameters = parameters.cloneReadOnly();
    }

    # Converts the given chunk into a vector embedding.
    #
    # + chunk - The chunk to be converted into an embedding
    # + return - The embedding vector representation on success, or an `ai:Error` if the operation fails
    isolated remote function embed(ai:Chunk chunk) returns ai:Embedding|ai:Error {
        observe:EmbeddingSpan span = observe:createEmbeddingSpan(self.modelType);
        span.addProvider("ollama");

        if chunk !is ai:TextDocument|ai:TextChunk {
            ai:Error err = error("Unsupported chunk type. only 'ai:TextDocument|ai:TextChunk' is supported");
            span.close(err);
            return err;
        }

        do {
            string content = chunk.content;
            span.addInputContent(content);
            // Ollama embeddings API reference:
            // https://github.com/ollama/ollama/blob/main/docs/api.md#generate-embeddings
            OllamaEmbeddingResponse response =
                check self.ollamaClient->/api/embed.post(self.buildRequestPayload(content));
            span.addResponseModel(response.model);
            int? inputTokens = response.prompt_eval_count;
            if inputTokens is int {
                span.addInputTokenCount(inputTokens);
            }

            float[][] embeddings = response.embeddings;
            if embeddings.length() == 0 {
                ai:Error err = error("No embeddings were returned for the provided chunk");
                span.close(err);
                return err;
            }

            ai:Embedding embedding = embeddings[0];
            span.close();
            return embedding;
        } on fail error e {
            ai:Error err = error("Unable to obtain embedding for the provided chunk", e);
            span.close(err);
            return err;
        }
    }

    # Converts a batch of chunks into vector embeddings.
    #
    # + chunks - The array of chunks to be converted into embeddings
    # + return - An array of embeddings on success, or an `ai:Error` if the operation fails
    isolated remote function batchEmbed(ai:Chunk[] chunks) returns ai:Embedding[]|ai:Error {
        observe:EmbeddingSpan span = observe:createEmbeddingSpan(self.modelType);
        span.addProvider("ollama");

        if !isAllTextChunks(chunks) {
            ai:Error err = error("Unsupported chunk type. only 'ai:TextChunk[]|ai:TextDocument[]' is supported");
            span.close(err);
            return err;
        }

        do {
            string[] input = chunks.map(chunk => chunk.content.toString());
            span.addInputContent(input);
            OllamaEmbeddingResponse response =
                check self.ollamaClient->/api/embed.post(self.buildRequestPayload(input));
            span.addResponseModel(response.model);
            int? inputTokens = response.prompt_eval_count;
            if inputTokens is int {
                span.addInputTokenCount(inputTokens);
            }

            float[][] embeddings = response.embeddings;
            if embeddings.length() != chunks.length() {
                ai:Error err = error(string `Expected ${chunks.length()} embedding(s) for the provided ` +
                    string `chunks, but received ${embeddings.length()}.`);
                span.close(err);
                return err;
            }

            ai:Embedding[] result = from float[] embedding in embeddings
                select embedding;
            span.close();
            return result;
        } on fail error e {
            ai:Error err = error("Unable to obtain embeddings for the provided chunks", e);
            span.close(err);
            return err;
        }
    }

    # Builds the request payload for the Ollama `/api/embed` endpoint.
    #
    # + input - A single input string or an array of input strings to embed
    # + return - The request payload to be sent to the Ollama embeddings endpoint
    private isolated function buildRequestPayload(string|string[] input) returns map<json> {
        OllamaEmbeddingModelParameters parameters = self.parameters;
        map<json> payload = {
            model: self.modelType,
            input,
            truncate: parameters.truncate
        };
        int? dimensions = parameters.dimensions;
        if dimensions is int {
            payload["dimensions"] = dimensions;
        }
        string? keepAlive = parameters.keepAlive;
        if keepAlive is string {
            payload["keep_alive"] = keepAlive;
        }
        return payload;
    }
}

# Checks whether every chunk in the given array is a text chunk or a text document.
#
# + chunks - The array of chunks to validate
# + return - `true` if all chunks are of type `ai:TextChunk` or `ai:TextDocument`; otherwise, `false`
isolated function isAllTextChunks(ai:Chunk[] chunks) returns boolean =>
    chunks.every(chunk => chunk is ai:TextChunk|ai:TextDocument);
