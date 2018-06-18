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

// Constants
@final string UTF_8 = "UTF-8";
@final string ISO_8859_1 = "ISO-8859-1";

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
