# Minecraft on demand with Terraform

## Overview

- Based on [https://github.com/doctorray117/minecraft-ondemand](doctorray117/minecraft-ondemand)
- Uses Terraform to deploy Minecraft Server to ECS
- Lambda points Route 53 domain to ECS task on startup
- Automatically shuts down with 0 active players
- Starts with Discord Bot integration

## Diagram of how this setup works:

![image](https://github.com/user-attachments/assets/6b935b15-a174-4e4c-9c42-92c28f64f3ca)


## TODOs

- Parametrise domain name and inactive player timeout
- publish housekeeper docker image with Github Actions
