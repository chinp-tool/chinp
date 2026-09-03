# chinp

Login analyzer for Linux servers

## Installation

English version:
curl -sSL https://raw.githubusercontent.com/chinp-tool/chinp/main/s/en/s/install/version/1/install.sh | sudo bash

## Usage

chinp <options>

## Description

chinp analyzes login attempts on the server, extracts IP addresses from logs, and shows geo information about each address.

## Features

- extract unique IPs from auth.log
- show country and city for each IP
- filter failed login attempts
- sort by frequency
- filter by port and protocol
- show anomalous activity

## Documentation

- [Command list](help.md)

## Requirements

- curl
- sudo privileges
