const { ECSClient, DescribeTasksCommand, ListTasksCommand, UpdateServiceCommand } = require("@aws-sdk/client-ecs");
const { EC2Client, DescribeNetworkInterfacesCommand } = require("@aws-sdk/client-ec2");
const { Route53Client, ChangeResourceRecordSetsCommand } = require("@aws-sdk/client-route-53");
const { Rcon } = require("rcon-client");

const region = "eu-west-1";

const ecsClient = new ECSClient({ region });
const ec2Client = new EC2Client({ region });
const route53Client = new Route53Client({ region });

async function getTaskIp(clusterName, serviceName) {
  try {
    const listTasksCommand = new ListTasksCommand({
      cluster: clusterName,
      serviceName: serviceName
    });
    const taskListResponse = await ecsClient.send(listTasksCommand);
    console.log("Task list response:", taskListResponse);
    if (taskListResponse.taskArns.length === 0) {
      throw new Error("No tasks found");
    }
    const taskId = taskListResponse.taskArns[0].split("/").pop();
    const describeTasksCommand = new DescribeTasksCommand({
      cluster: clusterName,
      tasks: [taskId]
    });
    const tasksResponse = await ecsClient.send(describeTasksCommand);
    const task = tasksResponse.tasks[0];
    const eniAttachment = task.attachments.find(att => att.type === 'ElasticNetworkInterface');
    const eniId = eniAttachment.details.find(detail => detail.name === 'networkInterfaceId').value;
    const describeNetworkInterfacesCommand = new DescribeNetworkInterfacesCommand({
      NetworkInterfaceIds: [eniId]
    });
    const eniData = await ec2Client.send(describeNetworkInterfacesCommand);
    const ipAddress = eniData.NetworkInterfaces[0].Association.PublicIp;
    return ipAddress;
  } catch (error) {
    console.error("Failed to get task IP:", error);
    throw error;
  }
}

async function updateDnsRecord(hostedZoneId, recordName, ipAddress) {
  try {
    const changeBatch = {
      Changes: [
        {
          Action: "UPSERT",
          ResourceRecordSet: {
            Name: recordName,
            Type: "A",
            TTL: 60,
            ResourceRecords: [{ Value: ipAddress }]
          }
        }
      ]
    };
    const params = {
      HostedZoneId: hostedZoneId,
      ChangeBatch: changeBatch
    };

    const command = new ChangeResourceRecordSetsCommand(params);
    const route53Response = await route53Client.send(command);
    console.log("DNS record updated:", route53Response);
  } catch (error) {
    console.error("Failed to update DNS record:", error);
    throw error;
  }
}

async function watchServer(host, password, port = 25575) {
  await new Promise(resolve => setTimeout(resolve, 1000 * 60 * 5)); // Sleep for 5 minutes to give the server time to start up
  const rcon = new Rcon({ host, password, port });
  await rcon.connect();
  console.log("Watching server at:", host);
  let keepRunning = true;
  let emptyCount = 0;
  while (keepRunning) {
    const response = await rcon.send("list");
    const countString = response.split(" ")[2]
    const count = parseInt(countString)

    const onlinePlayers = count;
    console.log("Online players:", onlinePlayers);
    if (onlinePlayers === 0) {
      emptyCount++;
      if (emptyCount > 5) {
        keepRunning = false;
        console.log("Server is empty, stopping");
        break;
      }
    } else {
      emptyCount = 0;
    }

    await new Promise(resolve => setTimeout(resolve, 5000)); // Sleep for 5 seconds
  }

  //set ecs task desired count to 0
  console.log("Stopping server");
  await ecsClient.send(new UpdateServiceCommand({
    cluster: clusterName,
    service: serviceName,
    desiredCount: 0
  }));

  const response = await rcon.send("stop");
  console.log("Server stopped:", response);
  await rcon.end();
  console.log("Server connection closed");
}

// Usage example
const clusterName = 'my-ecs-cluster';
const serviceName = 'minecraft-ondemand-terraform';
const hostedZoneId = 'Z05279451O9I6EYV5TDX';
const recordName = `minecraft.wiktorkowalski.pl`;

const password = process.env.RCON_PASSWORD ?? "yourpassword";

(async () => {
  console.log("Updating DNS record");
  const ipAddress = await getTaskIp(clusterName, serviceName);
  console.log("Got IP:", ipAddress);
  await updateDnsRecord(hostedZoneId, recordName, ipAddress);
  console.log("Updated DNS record with IP:", ipAddress);
  const privateIpAddress = ipAddress; //todo: get private ip from task
  await watchServer(privateIpAddress, password);
  console.log("Shutting down");
})();
