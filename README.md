# BWRP - Blockchain Wholesale Roaming Project

This repository contains all setup files for joining the production network.
It is based on Kubernetes and provides scripts for generating crypto material and starting pods as well as configuration files. 
For a general description of this project's software architechture, components and workflows, please check the [wiki page](https://github.com/GSMA-CPAS/BWRP).

## Pre-requisites

Ubuntu Linux LTS 16.04 and Above
2 CPU Machine and Above
4 Gb RAM and Above

Either AWS Ubuntu Instance or Standalone 
machine/network with static IP can also be used

Update the Hostname of the machine by updating below files -
- /etc/hosts
- /etc/hostname

Make sure you "reboot" the instance to bring hostname changes into effect.
And use this new hostname in further "docker" and "kubernetes" installation processes.

## Contributors

Our commitment to open source means that we are enabling -in fact encouraging- all interested parties to contribute and become part of its developer community.

## Licensing

Copyright (c) 2022 GSMA and all other contributors.

Licensed under the **Apache License, Version 2.0** (the "License"); you may not use this file except in compliance with the License.

You may obtain a copy of the License at https://www.apache.org/licenses/LICENSE-2.0.

Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the [LICENSE](./LICENSE) for the specific language governing permissions and limitations under the License.
