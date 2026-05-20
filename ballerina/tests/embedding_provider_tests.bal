// Copyright (c) 2025 WSO2 LLC. (http://www.wso2.org).
//
// WSO2 Inc. licenses this file to you under the Apache License,
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
import ballerina/test;

final EmbeddingProvider embeddingProvider = check new (EMBEDDING_MODEL, EMBEDDING_SERVICE_URL);
final EmbeddingProvider embeddingProviderWithDimensions =
    check new (EMBEDDING_MODEL, EMBEDDING_SERVICE_URL, {dimensions: 256});
final EmbeddingProvider embeddingProviderWithKeepAlive =
    check new (EMBEDDING_MODEL, EMBEDDING_SERVICE_URL, {keepAlive: "10m"});
final EmbeddingProvider embeddingProviderWithTruncateFalse =
    check new (EMBEDDING_MODEL, EMBEDDING_SERVICE_URL, {truncate: false});

@test:Config {groups: ["embeddings"]}
function testEmbedWithTextDocument() returns ai:Error? {
    ai:TextDocument document = {content: "single happy document"};
    ai:Embedding embedding = check embeddingProvider->embed(document);
    test:assertEquals(embedding, mockEmbeddingVector);
}

@test:Config {groups: ["embeddings"]}
function testEmbedWithTextChunk() returns ai:Error? {
    ai:TextChunk chunk = {content: "single happy chunk"};
    ai:Embedding embedding = check embeddingProvider->embed(chunk);
    test:assertEquals(embedding, mockEmbeddingVector);
}

@test:Config {groups: ["embeddings"]}
function testEmbedWithoutUsageMetadata() returns ai:Error? {
    ai:TextChunk chunk = {content: "single no-usage example"};
    ai:Embedding embedding = check embeddingProvider->embed(chunk);
    test:assertEquals(embedding, mockEmbeddingVector);
}

@test:Config {groups: ["embeddings"]}
function testEmbedWithUnsupportedChunkType() {
    ai:Chunk chunk = {'type: "image", content: "image data"};
    ai:Embedding|ai:Error embedding = embeddingProvider->embed(chunk);
    if embedding !is ai:Error {
        test:assertFail("Expected an error for an unsupported chunk type");
    }
    test:assertEquals(embedding.message(),
        "Unsupported chunk type. only 'ai:TextDocument|ai:TextChunk' is supported");
}

@test:Config {groups: ["embeddings"]}
function testEmbedWithEmptyEmbeddings() {
    ai:TextChunk chunk = {content: "single empty output"};
    ai:Embedding|ai:Error embedding = embeddingProvider->embed(chunk);
    if embedding !is ai:Error {
        test:assertFail("Expected an error when no embeddings are returned");
    }
    test:assertEquals(embedding.message(), "No embeddings were returned for the provided chunk");
}

@test:Config {groups: ["embeddings"]}
function testEmbedWithHttpError() {
    ai:TextChunk chunk = {content: "single http-error scenario"};
    ai:Embedding|ai:Error embedding = embeddingProvider->embed(chunk);
    if embedding !is ai:Error {
        test:assertFail("Expected an error for a failed HTTP request");
    }
    test:assertEquals(embedding.message(), "Unable to obtain embedding for the provided chunk");
}

@test:Config {groups: ["embeddings"]}
function testEmbedWithMalformedResponse() {
    ai:TextChunk chunk = {content: "single malformed payload"};
    ai:Embedding|ai:Error embedding = embeddingProvider->embed(chunk);
    if embedding !is ai:Error {
        test:assertFail("Expected an error for a malformed response");
    }
    test:assertEquals(embedding.message(), "Unable to obtain embedding for the provided chunk");
}

@test:Config {groups: ["embeddings"]}
function testBatchEmbedWithTextChunks() returns ai:Error? {
    ai:TextChunk[] chunks = [
        {content: "batch happy first"},
        {content: "batch happy second"}
    ];
    ai:Embedding[] embeddings = check embeddingProvider->batchEmbed(chunks);
    test:assertEquals(embeddings, [mockEmbeddingVector, mockEmbeddingVector]);
}

@test:Config {groups: ["embeddings"]}
function testBatchEmbedWithTextDocuments() returns ai:Error? {
    ai:TextDocument[] documents = [
        {content: "batch happy doc one"},
        {content: "batch happy doc two"},
        {content: "batch happy doc three"}
    ];
    ai:Embedding[] embeddings = check embeddingProvider->batchEmbed(documents);
    test:assertEquals(embeddings, [mockEmbeddingVector, mockEmbeddingVector, mockEmbeddingVector]);
}

@test:Config {groups: ["embeddings"]}
function testBatchEmbedWithoutUsageMetadata() returns ai:Error? {
    ai:TextChunk[] chunks = [
        {content: "batch no-usage first"},
        {content: "batch no-usage second"}
    ];
    ai:Embedding[] embeddings = check embeddingProvider->batchEmbed(chunks);
    test:assertEquals(embeddings, [mockEmbeddingVector, mockEmbeddingVector]);
}

@test:Config {groups: ["embeddings"]}
function testBatchEmbedWithUnsupportedChunkType() {
    ai:TextChunk validChunk = {content: "batch happy first"};
    ai:Chunk invalidChunk = {'type: "image", content: "image data"};
    ai:Chunk[] chunks = [validChunk, invalidChunk];
    ai:Embedding[]|ai:Error embeddings = embeddingProvider->batchEmbed(chunks);
    if embeddings !is ai:Error {
        test:assertFail("Expected an error for an unsupported chunk type");
    }
    test:assertEquals(embeddings.message(),
        "Unsupported chunk type. only 'ai:TextChunk[]|ai:TextDocument[]' is supported");
}

@test:Config {groups: ["embeddings"]}
function testBatchEmbedWithCountMismatch() {
    ai:TextChunk[] chunks = [
        {content: "batch mismatch first"},
        {content: "batch mismatch second"}
    ];
    ai:Embedding[]|ai:Error embeddings = embeddingProvider->batchEmbed(chunks);
    if embeddings !is ai:Error {
        test:assertFail("Expected an error when the embedding count does not match the chunk count");
    }
    test:assertEquals(embeddings.message(),
        "Expected 2 embedding(s) for the provided chunks, but received 1.");
}

@test:Config {groups: ["embeddings"]}
function testBatchEmbedWithHttpError() {
    ai:TextChunk[] chunks = [
        {content: "batch http-error first"},
        {content: "batch http-error second"}
    ];
    ai:Embedding[]|ai:Error embeddings = embeddingProvider->batchEmbed(chunks);
    if embeddings !is ai:Error {
        test:assertFail("Expected an error for a failed HTTP request");
    }
    test:assertEquals(embeddings.message(), "Unable to obtain embeddings for the provided chunks");
}

@test:Config {groups: ["embeddings"]}
function testEmbedWithCustomDimensions() returns ai:Error? {
    ai:TextChunk chunk = {content: "dimset single request"};
    ai:Embedding embedding = check embeddingProviderWithDimensions->embed(chunk);
    test:assertEquals(embedding, mockEmbeddingVector);
}

@test:Config {groups: ["embeddings"]}
function testEmbedWithKeepAlive() returns ai:Error? {
    ai:TextChunk chunk = {content: "keepset single request"};
    ai:Embedding embedding = check embeddingProviderWithKeepAlive->embed(chunk);
    test:assertEquals(embedding, mockEmbeddingVector);
}

@test:Config {groups: ["embeddings"]}
function testEmbedWithTruncateDisabled() returns ai:Error? {
    ai:TextChunk chunk = {content: "truncoff single request"};
    ai:Embedding embedding = check embeddingProviderWithTruncateFalse->embed(chunk);
    test:assertEquals(embedding, mockEmbeddingVector);
}

@test:Config {groups: ["embeddings"]}
function testEmbedProviderInitWithDefaultServiceUrl() {
    EmbeddingProvider|ai:Error result = new (EMBEDDING_MODEL);
    test:assertTrue(result is EmbeddingProvider,
        "Expected successful initialization with the default service URL");
}

@test:Config {groups: ["embeddings"]}
function testEmbedProviderInitFailure() {
    EmbeddingProvider|ai:Error result = new (EMBEDDING_MODEL, "http://invalid host:8081");
    if result !is ai:Error {
        test:assertFail("Expected an error when initializing with an invalid service URL");
    }
    test:assertEquals(result.message(), "Error while connecting to the embedding model");
}
