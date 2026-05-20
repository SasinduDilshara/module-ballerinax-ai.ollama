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

import ballerina/http;
import ballerina/test;

const EMBEDDING_MODEL = "all-minilm";
const EMBEDDING_SERVICE_URL = "http://localhost:8081/llm";

// A fixed embedding vector returned by the mock service for every input.
final readonly & float[] mockEmbeddingVector = [0.010071029, -0.0017594862, 0.05007221, 0.04692972];

// Mock implementation of the Ollama `/api/embed` endpoint.
// Behaviour is driven by markers contained in the first input string:
// `batch*` (array input), `dimset`, `keepset`, `truncoff`, `http-error`,
// `malformed`, `empty`, `mismatch` and `no-usage`.
service /llm on new http:Listener(8081) {
    resource function post api/embed(map<json> payload)
            returns OllamaEmbeddingResponse|http:Response|error {
        // The embedding model must always be present in the request.
        test:assertEquals(payload["model"], EMBEDDING_MODEL);

        // The `input` field may be a single string or an array of strings.
        json input = payload["input"];
        string[] inputs;
        if input is string {
            inputs = [input];
        } else if input is json[] {
            inputs = from json item in input
                select check item.ensureType();
        } else {
            return error("The `input` field must be a string or an array of strings");
        }
        test:assertTrue(inputs.length() > 0, "Expected at least one input");
        string marker = inputs[0];

        // Single-input calls must send a string; batch calls must send an array.
        if marker.startsWith("batch") {
            test:assertTrue(input is json[], "Batch calls must send an array input");
        } else {
            test:assertTrue(input is string, "Single calls must send a string input");
        }

        // Verify the advanced parameters carried in the request payload.
        if marker.includes("dimset") {
            test:assertEquals(payload["dimensions"], 256);
        } else {
            test:assertFalse(payload.hasKey("dimensions"), "Did not expect `dimensions` in the payload");
        }
        if marker.includes("keepset") {
            test:assertEquals(payload["keep_alive"], "10m");
        } else {
            test:assertFalse(payload.hasKey("keep_alive"), "Did not expect `keep_alive` in the payload");
        }
        test:assertEquals(payload["truncate"], !marker.includes("truncoff"));

        // Error scenarios.
        if marker.includes("http-error") {
            return createResponse(500, {message: "internal server error"});
        }
        if marker.includes("malformed") {
            return createResponse(200, {model: EMBEDDING_MODEL, embeddings: "not-a-vector"});
        }

        // Determine how many embedding vectors to return.
        int count = inputs.length();
        if marker.includes("empty") {
            count = 0;
        } else if marker.includes("mismatch") {
            count = inputs.length() - 1;
        }
        float[][] embeddings = [];
        foreach int _ in 0 ..< count {
            embeddings.push(mockEmbeddingVector);
        }

        OllamaEmbeddingResponse response = {
            model: EMBEDDING_MODEL,
            embeddings,
            total_duration: 14143917,
            load_duration: 1019500
        };
        if !marker.includes("no-usage") {
            response.prompt_eval_count = inputs.length() * 4;
        }
        return response;
    }
}

isolated function createResponse(int statusCode, json body) returns http:Response {
    http:Response response = new;
    response.statusCode = statusCode;
    response.setJsonPayload(body);
    return response;
}
