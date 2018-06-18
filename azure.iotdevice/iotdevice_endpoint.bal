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
import ballerina/time;

// Endpoint
public type Client object {

    // Data structure that will hold config info and a connector
    public {
        DeviceConfiguration deviceConfig = {};
        DeviceConnector deviceConnector = new;
    }

    public function init (DeviceConfiguration deviceConfig);
    public function getCallerActions() returns DeviceConnector;

};

// Connector
public type DeviceConnector object {

    public {
        string resourceUri;
        string signingKey;
        string policyName;
        int expiryInSeconds;
        string token;

        http:Client clientEndpoint = new;
    }

    public function send (string deviceId, json message) returns boolean;

};

// Part of the DeviceClient object and passed as an input parameter to
// the connector when it is instantiated
public type DeviceConfiguration {

    string resourceUri;
    string signingKey;
    string policyName;
    int expiryInSeconds = 3600;

    // This type is a record defined in the http system library
    http:ClientEndpointConfig clientConfig = {};

};

// Constants
@final string UTF_8 = "UTF-8";
@final string ISO_8859_1 = "ISO-8859-1";

// =========== Implementation of the Endpoint
public function Client::init (DeviceConfiguration deviceConfig) {
    self.deviceConnector.resourceUri = deviceConfig.resourceUri;
    self.deviceConnector.signingKey = deviceConfig.signingKey;
    self.deviceConnector.policyName = deviceConfig.policyName;
    self.deviceConnector.expiryInSeconds = deviceConfig.expiryInSeconds;

    self.deviceConnector.token = generateSasToken(
        self.deviceConnector.resourceUri, self.deviceConnector.signingKey, self.deviceConnector.policyName, self.deviceConnector.expiryInSeconds
    );

    self.deviceConnector.clientEndpoint.init(deviceConfig.clientConfig);
}

public function Client::getCallerActions () returns DeviceConnector {
    return self.deviceConnector;
}
// =========== End of implementation of the Endpoint

// =========== Implementation for Connector
public function DeviceConnector::send (string deviceId, json message) returns boolean {
    endpoint http:Client clientEndpoint = self.clientEndpoint;

    http:Request request = new;
    request.addHeader("authorization", self.token);
    request.setJsonPayload(message);

    boolean result = false;

    var httpResponse = clientEndpoint->post("/devices/" + deviceId + "/messages/events?api-version=2018-04-01", request);
    match httpResponse {
        error err => {
            result = false;
        }
        http:Response response => {
            result = (response.statusCode == 204);
        }
    }

    return result;
}
// =========== End of implementation for Connector

// Utility functions
function generateSasToken(string resourceUri, string signingKey, string policyName, int expiryInSeconds) returns string {
    time:Time time = time:currentTime();
    time = time.addDuration(0, 0, 0, 0, 0, expiryInSeconds, 0);
    string expiry = <string> (time.time / 1000);

    string signingKeyDecoded = check signingKey.base64Decode(charset = ISO_8859_1);
    string resourceUriEncoded = check http:encode(resourceUri, UTF_8);
    string stringToSign = resourceUriEncoded + "\n" + expiry;
    string hmacResult = crypto:hmac(stringToSign, signingKeyDecoded, crypto:SHA256);
    string signature = hmacResult.base16ToBase64Encode();
    string signatureEncoded = check http:encode(signature, UTF_8);

    string token = string `SharedAccessSignature sr={{resourceUriEncoded}}&sig={{signatureEncoded}}&se={{expiry}}`;
    if (policyName.length() > 0) {
        token += string `&skn={{policyName}}`;
    }

    return token;
}
