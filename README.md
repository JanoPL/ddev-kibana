# DDEV Kibana Add-on

[![tests](https://github.com/janopl/ddev-kibana/actions/workflows/tests.yml/badge.svg)](https://github.com/janopl/ddev-kibana/actions/workflows/tests.yml) ![project is maintained](https://img.shields.io/maintenance/yes/2025.svg)

Install and configure Kibana in your DDEV environment. This add-on provides a seamless integration with Elasticsearch
for data visualization and analytics.

## Instalation

Uses [Kibana official image](https://registry.hub.docker.com/_/kibana)

For DDEV v1.23.5 or above run

```sh
ddev add-on get janopl/ddev-kibana
```

For earlier versions of DDEV run

```sh
ddev get janopl/ddev-kibana
```

## Features

- Easy integration with DDEV environment
- Support for multiple Kibana versions
- Custom configuration options
- Secure HTTPS access
- Health monitoring

## Configuration

### Default Settings

- Container hostname: "kibana"
- Default port: 5601
- Automatic health checks enabled

### Version Configuration

You can customize the Kibana version to match your Elasticsearch installation.

```docker-compose.kibana.yml```
```
services:
    kibana:
        build:
            ...
            args:
                - KIBANA_VERSION=7.17.14 // example: 8.10.2
        ...
        environment:
            KIBANA_VERSION: 7.17.14 // example: 8.10.2
```

OR 

After adding the add-on, run ```cp .ddev/elasticsearch/docker-compose.elasticsearch8.yaml .ddev/``` to enable Kibana 8.

### Configuration file
You can configure Kibana dashboard through the config file under: ```.ddev/kibana/config.yml```

## Access and Usage

Access the Kibana dashboard through your browser:

- HTTPS: `https://<projectname>.ddev.site:5601` (Recommended)
- HTTP: `http://<projectname>.ddev.site:5600`

## Troubleshooting

Common issues and solutions:

1. If Kibana fails to start, ensure Elasticsearch is running and healthy
2. Check the logs using `ddev logs -s kibana`
3. Verify the version compatibility between Kibana and Elasticsearch
4. Ensure the configuration file is properly formatted

## Contribution

First off, thanks for taking the time to contribute! Contributions are what make the open-source community such an amazing place to learn, inspire, and create. Any contributions you make will benefit everybody else and are **greatly appreciated**.


Please read [our contribution guidelines](./docs/CONTRIBUTING.md), and thank you for being involved!

## License

This project is licensed under the **APACHE license**.

See [LICENSE](LICENSE) for more information.
