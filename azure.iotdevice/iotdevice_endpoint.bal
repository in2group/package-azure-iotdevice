// Copyright (c) 2018, IN2 Ltd. (http://www.in2.hr) All Rights Reserved.
//
// IN2 Ltd. licenses this file to you under the Apache License,
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
import ballerina/system;
import ballerina/time;
import in2/crypto;
import ballerina/io;

// Endpoint
public type Client object {

    // Data structure that will hold config info and a connector
    public DeviceConnector deviceConnector = new;

    public function init (DeviceConfiguration deviceConfig);
    public function getCallerActions() returns DeviceConnector;

};

// Connector
public type DeviceConnector object {

    public string hostName;
    public string deviceId;
    public string sharedAccessKey;
    public string policyName;
    public int expiryInSeconds;
    public string token;

    public http:Client clientEndpoint = new;

    public function send (json message, boolean batch = false) returns (int|error);

};

// Part of the DeviceClient object and passed as an input parameter to
// the connector when it is instantiated
public type DeviceConfiguration record {

    string connectionString;
    int expiryInSeconds = 3600;

    // This type is a record defined in the http system library
    http:ClientEndpointConfig clientConfig = {};

};

// Constants
@final string UTF_8 = "UTF-8";
@final string BATCH_MESSAGE_CONTENT_TYPE = "application/vnd.microsoft.iothub.json";

@final map<string> IOT_HUB_ERROR_CODES = {
    "400": "The body of the request is not valid; for example, it cannot be parsed, or the object cannot be validated.",
    "401": "The authorization token cannot be validated; for example, it is expired or does not apply to the request’s URI and/or method.",
    "404": "The IoT Hub instance or a device identity does not exist.",
    "403": "The maximum number of device identities has been reached.",
    "412": "The etag in the request does not match the etag of the existing resource, as per RFC7232.",
    "429": "This IoT Hub’s identity registry operations are being throttled by the service. For more information, see IoT Hub Developer Guide – Throttling for more information. An exponential back-off strategy is recommended.",
    "500": "An internal error occurred."
};

// =========== Implementation of the Endpoint
function Client::init (DeviceConfiguration deviceConfig) {
    var splitted = deviceConfig.connectionString
        .replace("HostName=","")
        .replace("DeviceId=","")
        .replace("SharedAccessKey=","")
        .split(";");

    if (lengthof splitted != 3) {
        error err = {
            message: "Connection string should be in format HostName=<...>;DeviceId=<...>;SharedAccessKey=<...>"
        };
        throw err;
    }

    self.deviceConnector.hostName = splitted[0];
    self.deviceConnector.deviceId = splitted[1];
    self.deviceConnector.sharedAccessKey = splitted[2];
    self.deviceConnector.expiryInSeconds = deviceConfig.expiryInSeconds;

    self.deviceConnector.token = createSasToken(
        self.deviceConnector.hostName, self.deviceConnector.sharedAccessKey, self.deviceConnector.policyName, self.deviceConnector.expiryInSeconds
    );

    deviceConfig.clientConfig.url = string `https://{{self.deviceConnector.hostName}}`;
    self.deviceConnector.clientEndpoint.init(deviceConfig.clientConfig);
}

function Client::getCallerActions () returns DeviceConnector {
    return self.deviceConnector;
}
// =========== End of implementation of the Endpoint

// =========== Implementation for Connector
function DeviceConnector::send (json message, boolean batch = false) returns (int|error) {
    endpoint http:Client clientEndpoint = self.clientEndpoint;
    int messageCount = 0;
    http:Request request = new;

    if (batch && lengthof message != -1) {
        messageCount = lengthof message;
        request.setJsonPayload(createBatchMessage(message));
        request.setContentType(BATCH_MESSAGE_CONTENT_TYPE);
    } else {
        messageCount = 1;
        request.setJsonPayload(createSingleMessage(message));
    }
    request.addHeader("authorization", self.token);

    var httpResponse = clientEndpoint->post("/devices/" + self.deviceId + "/messages/events?api-version=2018-06-30", request);
    match httpResponse {
        error err => {
            return err;
        }
        http:Response response => {
            if (response.statusCode == 204) {
                return messageCount;
            } else {
                string statusCode = <string> response.statusCode;
                error err = {
                    message: statusCode + " " + (IOT_HUB_ERROR_CODES[statusCode] ?: "Unknown error occured.")
                };
                return err;
            }
        }
    }
}
// =========== End of implementation for Connector

// Utility functions
function createSasToken(string resourceUri, string signingKey, string policyName, int expiryInSeconds) returns string {
    time:Time time = time:currentTime();
    time = time.addDuration(0, 0, 0, 0, 0, expiryInSeconds, 0);
    string expiry = <string> (time.time / 1000);

    string resourceUriEncoded = check http:encode(resourceUri, UTF_8);
    string stringToSign = resourceUriEncoded + "\n" + expiry;
    string hmacResult = crypto:hmac(stringToSign, signingKey, crypto:SHA256, keyType = crypto:BASE64);
    string signature = hmacResult.base16ToBase64Encode();
    string signatureEncoded = check http:encode(signature, UTF_8);

    string token = string `SharedAccessSignature sr={{resourceUriEncoded}}&sig={{signatureEncoded}}&se={{expiry}}`;
    if (policyName.length() > 0) {
        token += string `&skn={{policyName}}`;
    }

    return token;
}

function createSingleMessage(json message) returns json {
    string correlationId = system:uuid();
    return {
        body: message,
        base64Encoded: false,
        properties: {
            "iothub-correlationid": correlationId,
            "iothub-messageid": correlationId,
            "iothub-app-temeraturealert": false
        }
    };
}

function createBatchMessage(json message) returns json {
    json result = [];
    string correlationId = system:uuid();

    foreach index, element in check <json[]> message {
        result[index] = createBatchElement(correlationId, element);
    }

    return result;
}

function createBatchElement(string correlationId, json message) returns json {
    return {
        body: check message.toString().base64Encode(),
        base64Encoded: true,
        properties: {
            "iothub-correlationid": correlationId,
            "iothub-messageid": system:uuid(),
            "iothub-app-temeraturealert": false
        }
    };
}
