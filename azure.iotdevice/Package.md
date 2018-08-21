Connects to Azure IoT Hub from Ballerina. 

# Package Overview

Ballerina Azure IoT Device Connector is used to connect Ballerina with Azure IoT Hub. With the Azure IoT Device Connector Ballerina can act as an IoT Device over HTTPS.

## Compatibility

| Ballerina Language Version | Azure IoT API version  |
| -------------------------- | ---------------------- |
| 0.981.0                    | 2018-06-30             |

## Sample

Sending single device message from Ballerina:

```ballerina
import ballerina/io;
import in2/azure.iotdevice as iot;

function main(string... args) {
  endpoint iot:Client deviceEndpoint {
    connectionString: "HostName=<...>;DeviceId=<...>;SharedAccessKey=<...>"
  }

  var result = deviceEndpoint->send({city: "Barcelona", temperature: 30});
  io:println(result);
}
```

Sending multiple device messages in batch from Ballerina:

```ballerina
import ballerina/io;
import in2/azure.iotdevice as iot;

function main(string... args) {
  endpoint iot:Client deviceEndpoint {
    connectionString: "HostName=<...>;DeviceId=<...>;SharedAccessKey=<...>"
  }

  var messages = [
      {city: "Barcelona", temperature: 30},
      {city: "Madrid", temperature: 25}
  ];

  var result = deviceEndpoint->send(messages, batch = true);
  match result {
        int count => io:println("messages sent: " + count);
        error err => io:println("error occured: " + err.message);
    }
}
```
