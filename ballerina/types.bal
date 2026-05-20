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

import ballerina/data.jsondata;
import ballerina/http;

# Configurations for controlling the behaviours when communicating with a remote HTTP endpoint.
@display {label: "Connection Configuration"}
public type ConnectionConfig record {|

    # The HTTP version understood by the client
    @display {label: "HTTP Version"}
    http:HttpVersion httpVersion = http:HTTP_2_0;

    # Configurations related to HTTP/1.x protocol
    @display {label: "HTTP1 Settings"}
    http:ClientHttp1Settings http1Settings?;

    # Configurations related to HTTP/2 protocol
    @display {label: "HTTP2 Settings"}
    http:ClientHttp2Settings http2Settings?;

    # The maximum time to wait (in seconds) for a response before closing the connection
    @display {label: "Timeout"}
    decimal timeout = 60;

    # The choice of setting `forwarded`/`x-forwarded` header
    @display {label: "Forwarded"}
    string forwarded = "disable";

    # Configurations associated with request pooling
    @display {label: "Pool Configuration"}
    http:PoolConfiguration poolConfig?;

    # HTTP caching related configurations
    @display {label: "Cache Configuration"}
    http:CacheConfig cache?;

    # Specifies the way of handling compression (`accept-encoding`) header
    @display {label: "Compression"}
    http:Compression compression = http:COMPRESSION_AUTO;

    # Configurations associated with the behaviour of the Circuit Breaker
    @display {label: "Circuit Breaker Configuration"}
    http:CircuitBreakerConfig circuitBreaker?;

    # Configurations associated with retrying
    @display {label: "Retry Configuration"}
    http:RetryConfig retryConfig?;

    # Configurations associated with inbound response size limits
    @display {label: "Response Limit Configuration"}
    http:ResponseLimitConfigs responseLimits?;

    # SSL/TLS-related options
    @display {label: "Secure Socket Configuration"}
    http:ClientSecureSocket secureSocket?;

    # Proxy server related options
    @display {label: "Proxy Configuration"}
    http:ProxyConfig proxy?;

    # Enables the inbound payload validation functionality which provided by the constraint package. Enabled by default
    @display {label: "Payload Validation"}
    boolean validation = true;
|};

// Configs obtained from: https://github.com/ollama/ollama/blob/main/docs/modelfile.md#parameter
# Represents the model parameters for Ollama text generation.
# These parameters control the behavior and output of the model.
@display {label: "Ollama Model Parameters"}
public type OllamaModelParameters record {|
    # Enable Mirostat sampling for controlling perplexity.  
    # - `0` = disabled  
    # - `1` = Mirostat  
    # - `2` = Mirostat 2.0  
    @display {label: "Mirostat Sampling"}
    0|1|2 mirostat = 0;

    # Influences how quickly the algorithm responds to feedback from the generated text.  
    # A lower value results in slower adjustments, while a higher value makes the model more responsive.  
    @jsondata:Name {value: "mirostat_eta"}
    @display {label: "Mirostat eta"}
    float mirostatEta = 0.1;

    # Controls the balance between coherence and diversity of the output.  
    # A lower value results in more focused and coherent text.  
    @jsondata:Name {value: "mirostat_tau"}
    @display {label: "Mirostat tau"}
    float mirostatTau = 5.0;

    # Sets the size of the context window used to generate the next token.  
    @jsondata:Name {value: "num_ctx"}
    @display {label: "Context Window Size"}
    int numCtx = 2048;

    # Sets how far back the model should look to prevent repetition.  
    # - `0` = disabled  
    # - `-1` = num_ctx  
    @jsondata:Name {value: "repeat_last_n"}
    @display {label: "Repeat Last N"}
    int repeatLastN = 64;

    # Sets how strongly to penalize repetitions.  
    # A higher value (e.g., `1.5`) will penalize repetitions more strongly,  
    # while a lower value (e.g., `0.9`) will be more lenient.  
    @jsondata:Name {value: "repeat_penalty"}
    @display {label: "Repeat Penalty"}
    float repeatPenalty = 1.1;

    # Controls the creativity of the model's responses.  
    # A higher value makes the output more diverse, while a lower value makes it more focused.  
    @display {label: "Temperature"}
    float temperature = 0.8;

    # Sets the random number seed for deterministic text generation.  
    # A specific value ensures the same output for identical prompts.  
    @display {label: "Seed"}
    int seed = 0;

    # Maximum number of tokens to generate.  
    # `-1` allows infinite generation.  
    @jsondata:Name {value: "num_predict"}
    @display {label: "Number of Tokens to Predict"}
    int numPredict = -1;

    # Controls randomness by selecting the top-k most likely next words.  
    # A higher value (e.g., `100`) increases diversity,  
    # while a lower value (e.g., `10`) makes responses more conservative.  
    @jsondata:Name {value: "top_k"}
    @display {label: "Top K"}
    int topK = 40;

    # Controls randomness by considering the cumulative probability of choices.  
    # A higher value (e.g., `0.95`) increases diversity,  
    # while a lower value (e.g., `0.5`) makes responses more conservative.  
    @jsondata:Name {value: "top_p"}
    @display {label: "Top P"}
    float topP = 0.9;

    # Ensures a balance between quality and variety.  
    # Filters out low-probability tokens relative to the highest probability token.  
    @jsondata:Name {value: "min_p"}
    @display {label: "Min P"}
    float minP = 0.0;
|};

// https://github.com/ollama/ollama/blob/main/docs/api.md#response-36
type OllamaResponse record {
    string model;
    OllamaMessage message;
    string done_reason?;
    int prompt_eval_count?;
    int eval_count?;
};

type OllamaMessage record {
    string role;
    string content;
    OllamaToolCall[] tool_calls?;
};

type OllamaToolCall record {
    OllamaFunction 'function;
};

type OllamaFunction record {
    string name;
    map<json> arguments;
};

const FUNCTION = "function";

// Configs obtained from: https://github.com/ollama/ollama/blob/main/docs/api.md#generate-embeddings
# Represents the advanced parameters for generating embeddings with Ollama.
# These parameters control the behaviour of the Ollama `/api/embed` endpoint.
@display {label: "Ollama Embedding Model Parameters"}
public type OllamaEmbeddingModelParameters record {|
    # The number of dimensions for the output embedding.
    # When not specified, the model's default dimensionality is used.
    # Only effective for models that support shortening the embedding dimension.
    @display {label: "Dimensions"}
    int dimensions?;

    # Truncates the end of each input to fit within the model's context length.
    # When set to `false`, the request fails with an error if the context length is exceeded.
    @display {label: "Truncate"}
    boolean truncate = true;

    # Controls how long the model stays loaded in memory following the request (e.g., `"5m"`).
    @display {label: "Keep Alive"}
    string keepAlive?;
|};

// https://github.com/ollama/ollama/blob/main/docs/api.md#generate-embeddings
type OllamaEmbeddingResponse record {
    string model;
    float[][] embeddings;
    int total_duration?;
    int load_duration?;
    int prompt_eval_count?;
};
