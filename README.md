# Ballerina Azure IoT Device Connector

Ballerina Azure IoT Device Connector is used to connect Ballerina with Azure IoT Hub. With the Azure IoT Device Connector Ballerina can act as an IoT Device over HTTPS.

## Compatibility

| Ballerina Language Version | Azure IoT API version  |
| -------------------------- | ---------------------- |
| 0.990.0                    | 2018-06-30             |

## Sample

Sending single device message from Ballerina:

```ballerina
import ballerina/io;
import in2/azure.iotdevice as iot;

public function main(string... args) {
  iot:Client deviceClient = new({
    connectionString: "HostName=<...>;DeviceId=<...>;SharedAccessKey=<...>"
  });

  var result = deviceClient->send({city: "Barcelona", temperature: 30});
  io:println(result);
}
```

Sending multiple device messages in batch from Ballerina:

```ballerina
import ballerina/io;
import in2/azure.iotdevice as iot;

public function main(string... args) {
  iot:Client deviceClient = new({
    connectionString: "HostName=<...>;DeviceId=<...>;SharedAccessKey=<...>"
  });

  var messages = [
      {city: "Barcelona", temperature: 30},
      {city: "Madrid", temperature: 25}
  ];

  var result = deviceClient->send(messages, batch = true);
  if (result is error) {
    io:println("error occured: " + result.reason());
  } else {
    io:println("messages sent: " + result);
  }
}
```
