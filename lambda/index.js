const { ECSClient, UpdateServiceCommand } = require("@aws-sdk/client-ecs");
const nacl = require("tweetnacl");

const PUBLIC_KEY = '1dbf0767b757d3b3bc573cdb27af469166604a5ed6e9ba4fa9e92f652ce0c2e6';

exports.handler = async (event) => {
  console.log("Received event:", event);

  const body = JSON.parse(event.body);

  if(body){
    console.log("Received body:", body);
    
    const signature = event.headers["x-signature-ed25519"];
    const timestamp = event.headers["x-signature-timestamp"];
    
    console.log("Received signature:", signature);
    console.log("Received timestamp:", timestamp);
    
    const isVerified = nacl.sign.detached.verify(
      Buffer.from(timestamp + JSON.stringify(body)),
      Buffer.from(signature, "hex"),
      Buffer.from(PUBLIC_KEY, "hex")
      );
      
      console.log("Verification result:", isVerified);
      
      if (!isVerified) {
        console.error("Invalid request signature");
        return {
          statusCode: 401,
          body: JSON.stringify({ error: "invalid request signature" }),
        };
      }
      
      if (body && body.type === 1) {
        console.log("Received ping event");
        return {
          statusCode: 200,
          body: JSON.stringify({
            type: 1
          }),
        };
      }
    }
      
    const clusterName = process.env.CLUSTER_NAME;
    const serviceName = process.env.SERVICE_NAME;

    const ecsClient = new ECSClient({ region: "eu-west-1" });
  
    const params = {
      cluster: clusterName,
      service: serviceName,
      desiredCount: 1,
    };
  
    const command = new UpdateServiceCommand(params);
  
    try {
      const response = await ecsClient.send(command);
      console.log("Service updated successfully:", response);
      console.log(`Successfully set desired task count to 1 for service ${serviceName} in cluster ${clusterName}.`);
      return {
        statusCode: 200,
        body: JSON.stringify({
          type: 4,
          data: {
            content: `Successfully set desired task count to 1 for service ${serviceName} in cluster ${clusterName}.`
          }
        }),
      };
    } catch (error) {
      console.error("Error updating service:", error);
      return {
        statusCode: 500,
        body: `Error setting desired task count: ${error}`,
      };
    }
  };