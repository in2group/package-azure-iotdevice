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

import ballerina/crypto;
import ballerina/http;
import ballerina/system;
import ballerina/time;

# Azure IoT Hub Client object.
#
# + hostName - The IoT Hub hostname in format <iothub-name>.azure-devices.net
# + deviceId - The name for the device
# + sharedAccessKey - The access key for the device
# + policyName - The access token of the Twitter account
# + expiryInSeconds - The message expiry in seconds
# + token - The generated access token for the device
# + deviceClient - HTTP Client endpoint
public type Client client object {
    string hostName;
    string deviceId;
    string sharedAccessKey;
    string policyName = "";
    int expiryInSeconds;
    string token;

    http:Client deviceClient;

    public function __init(DeviceConfiguration deviceConfig) {
        var splitted = deviceConfig.connectionString
            .replace("HostName=","")
            .replace("DeviceId=","")
            .replace("SharedAccessKey=","")
            .split(";");

        if (splitted.length() != 3) {
            error err = error("Connection string should be in format HostName=<Host Name>;SharedAccessKeyName=<Key Name>;SharedAccessKey=<SAS Key>");
            panic err;
        }

        self.hostName = splitted[0];
        self.deviceId = splitted[1];
        self.sharedAccessKey = splitted[2];
        self.expiryInSeconds = deviceConfig.expiryInSeconds;

        self.token = check createSasToken(
            self.hostName, self.sharedAccessKey, self.policyName, self.expiryInSeconds
        );

        self.deviceClient = new(
            string `https://{{self.hostName}}`,
            config = deviceConfig.clientConfig
        );
    }

    # Send the message to Azure IoT Hub.
    #
    # + message - The message to be sent
    # + batch - Indicator if message should be sent in batch
    # + return - If success, returns number of messages sent, else returns error
    public remote function send (json message, boolean batch = false) returns int|error;
};

# Azure IoT Hub Connector configurations can be setup here.
#
# + connectionString - The connection string for Azure Iot Hub in format HostName=<Host Name>;SharedAccessKeyName=<Key Name>;SharedAccessKey=<SAS Key>
# + expiryInSeconds - The message expiry in seconds
# + clientConfig - Client endpoint configurations provided by the user
public type DeviceConfiguration record {
    string connectionString;
    int expiryInSeconds = 3600;
    http:ClientEndpointConfig clientConfig = {};
};

// Constants
final string UTF_8 = "UTF-8";
final string BATCH_MESSAGE_CONTENT_TYPE = "application/vnd.microsoft.iothub.json";

final map<string> IOT_HUB_ERROR_CODES = {
    "400": "The body of the request is not valid; for example, it cannot be parsed, or the object cannot be validated.",
    "401": "The authorization token cannot be validated; for example, it is expired or does not apply to the request’s URI and/or method.",
    "404": "The IoT Hub instance or a device identity does not exist.",
    "403": "The maximum number of device identities has been reached.",
    "412": "The etag in the request does not match the etag of the existing resource, as per RFC7232.",
    "429": "This IoT Hub’s identity registry operations are being throttled by the service. For more information, see IoT Hub Developer Guide – Throttling for more information. An exponential back-off strategy is recommended.",
    "500": "An internal error occurred."
};

// =========== Implementation for Connector
remote function Client.send (json message, boolean batch = false) returns int|error {
    http:Client deviceClient = self.deviceClient;
    int messageCount = 0;
    http:Request request = new;

    if (batch && message.length() != -1) {
        messageCount = message.length();
        request.setJsonPayload(check createBatchMessage(message));
        check request.setContentType(BATCH_MESSAGE_CONTENT_TYPE);
    } else {
        messageCount = 1;
        request.setJsonPayload(createSingleMessage(message));
    }
    request.addHeader("authorization", self.token);

    var response = deviceClient->post("/devices/" + self.deviceId + "/messages/events?api-version=2018-06-30", request);
    if (response is http:Response) {
        if (response.statusCode == 204) {
            return messageCount;
        } else {
            string statusCode = <string> response.statusCode;
            error err = error(statusCode + " " + (IOT_HUB_ERROR_CODES[statusCode] ?: "Unknown error occured."));
            return err;
        }
    } else {
        return response;
    }
}
// =========== End of implementation for Connector

// Utility functions
function createSasToken(string resourceUri, string signingKey, string policyName, int expiryInSeconds) returns string|error {
    time:Time time = time:currentTime();
    time = time.addDuration(0, 0, 0, 0, 0, expiryInSeconds, 0);
    string expiry = <string> (time.time / 1000);

    string resourceUriEncoded = check http:encode(resourceUri, UTF_8);
    string stringToSign = resourceUriEncoded + "\n" + expiry;
    string hmacResult = crypto:hmac(stringToSign, signingKey, crypto:SHA256, keyEncoding = "BASE64");
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

function createBatchMessage(json message) returns json|error {
    json result = [];
    string correlationId = system:uuid();

    if (message is json[]) {
        int index = 0;
        foreach json element in message {
            result[index] = check createBatchElement(correlationId, element);
        }
        index += 1;
    }

    return result;
}

function createBatchElement(string correlationId, json message) returns json|error {
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
