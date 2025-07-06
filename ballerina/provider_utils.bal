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
import ballerina/http;

type SchemaResponse record {|
    map<json> schema;
    boolean isOriginallyJsonObject = true;
|};

const JSON_CONVERSION_ERROR = "FromJsonStringError";
const CONVERSION_ERROR = "ConversionError";
const ERROR_MESSAGE = "Error occurred while attempting to parse the response from the " +
    "LLM as the expected type. Retrying and/or validating the prompt could fix the response.";
const RESULT = "result";
const GET_RESULTS_TOOL = "getResults";
const FUNCTION = "function";
const NO_RELEVANT_RESPONSE_FROM_THE_LLM = "No relevant response from the LLM";

isolated function generateJsonObjectSchema(map<json> schema) returns SchemaResponse {
    string[] supportedMetaDataFields = ["$schema", "$id", "$anchor", "$comment", "title", "description"];

    if schema["type"] == "object" {
        return {schema};
    }

    map<json> updatedSchema = map from var [key, value] in schema.entries()
        where supportedMetaDataFields.indexOf(key) is int
        select [key, value];

    updatedSchema["type"] = "object";
    map<json> content = map from var [key, value] in schema.entries()
        where supportedMetaDataFields.indexOf(key) !is int
        select [key, value];

    updatedSchema["properties"] = {[RESULT]: content};

    return {schema: updatedSchema, isOriginallyJsonObject: false};
}

isolated function parseResponseAsType(string resp,
        typedesc<anydata> expectedResponseTypedesc, boolean isOriginallyJsonObject) returns anydata|error {
    if !isOriginallyJsonObject {
        map<json> respContent = check resp.fromJsonStringWithType();
        anydata|error result = trap respContent[RESULT].fromJsonWithType(expectedResponseTypedesc);
        if result is error {
            return handleParseResponseError(result);
        }
        return result;
    }

    anydata|error result = resp.fromJsonStringWithType(expectedResponseTypedesc);
    if result is error {
        return handleParseResponseError(result);
    }
    return result;
}

isolated function getExpectedResponseSchema(typedesc<anydata> expectedResponseTypedesc) returns SchemaResponse|ai:Error {
    // Restricted at compile-time for now.
    typedesc<json> td = checkpanic expectedResponseTypedesc.ensureType();
    return generateJsonObjectSchema(check generateJsonSchemaForTypedescAsJson(td));
}

isolated function getGetResultsTool(map<json> parameters) returns map<json>[]|error {
    return [
        {
            'type: FUNCTION,
            'function: {
                name: GET_RESULTS_TOOL,
                parameters: parameters,
                description: string `Required Tool to call with the response from a large language model (LLM) for a user prompt. 
                            This tool is mandatory for the LLM to return a response.`
            }
        }
    ];
}

isolated function genarateChatCreationContent(ai:Prompt prompt) returns string|ai:Error {
    string[] & readonly strings = prompt.strings;
    string str = strings[0];
    anydata[] insertions = prompt.insertions;
    foreach int i in 0 ..< insertions.length() {
        anydata insertion = insertions[i];
        string promptStr = strings[i + 1];

        if insertion is ai:TextDocument {
            str += insertion.content + " " + promptStr;
            continue;
        }

        if insertion is ai:TextDocument[] {
            foreach ai:TextDocument doc in insertion {
                str += doc.content  + " ";
                
            }
            str += promptStr;
            continue;
        }

        if insertion is ai:Document {
            return error ai:Error("Only Text Documents are currently supported.");
        }

        str += insertion.toString() + promptStr;
    }
    return str.trim();
}

isolated function handleParseResponseError(error chatResponseError) returns error {
    if chatResponseError.message().includes(JSON_CONVERSION_ERROR)
            || chatResponseError.message().includes(CONVERSION_ERROR) {
        return error(string `${ERROR_MESSAGE}`, detail = chatResponseError);
    }
    return chatResponseError;
}

isolated function generateLlmResponse(http:Client llmClient, string modelType,
        readonly & map<json> modleParameters, ai:Prompt prompt, 
        typedesc<json> expectedResponseTypedesc) returns anydata|ai:Error {
    string content = check genarateChatCreationContent(prompt);
    SchemaResponse schemaResponse = check getExpectedResponseSchema(expectedResponseTypedesc);
    map<json>[]|error tools = getGetResultsTool(schemaResponse.schema);
    if tools is error {
        return error ai:LlmError("Error while generating the tool: " + tools.message());
    }

    map<json> request = {
        messages: [
            {
                role: ai:USER,
                "content": content
            }
        ],
        tools,
        model: modelType,
        'stream: false,
        options: {...modleParameters}
    };

    OllamaResponse|error response = llmClient->/api/chat.post(request);
    if response is error {
        return error ai:LlmConnectionError("Error while connecting to ollama", response);
    }

    OllamaToolCall[]? toolCalls = response.message?.tool_calls;

    if toolCalls is () || toolCalls.length() == 0 {
        return error ai:LlmError(NO_RELEVANT_RESPONSE_FROM_THE_LLM);
    }

    OllamaToolCall tool = toolCalls[0];
    map<json> arguments = tool.'function.arguments;

    anydata|error res = parseResponseAsType(arguments.toJsonString(), expectedResponseTypedesc,
            schemaResponse.isOriginallyJsonObject);
    if res is error {
        return error ai:LlmInvalidGenerationError(string `Invalid value returned from the LLM Client, expected: '${
            expectedResponseTypedesc.toBalString()}', found '${res.toBalString()}'`);
    }

    anydata|error result = res.ensureType(expectedResponseTypedesc);

    if result is error {
        return error ai:LlmInvalidGenerationError(string `Invalid value returned from the LLM Client, expected: '${
            expectedResponseTypedesc.toBalString()}', found '${(typeof response).toBalString()}'`);
    }
    return result;
}
